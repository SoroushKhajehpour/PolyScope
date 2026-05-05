# frozen_string_literal: true
require "ostruct"
require "digest"

class MarketsController < ApplicationController
  def index
    render inertia: "Home"
  end

  def live_search
    query = params[:q].to_s.strip
    @markets = if query.present?
      cache_key = "live_search:#{Digest::SHA256.hexdigest(query.downcase)}"
      cached = Rails.cache.read(cache_key)
      if cached
        ApiDiagnostics.record_call(service: "markets.live_search", cache_hit: true, deduped: true) if defined?(ApiDiagnostics)
        cached
      else
        results = search_results(query)
        Rails.cache.write(cache_key, results, expires_in: 60.seconds)
        ApiDiagnostics.record_call(service: "markets.live_search") if defined?(ApiDiagnostics)
        results
      end
    else
      []
    end

    render json: @markets.map { |m| serialize_search_result(m) }
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] live_search failed: #{e.message}")
    render json: [], status: :ok
  end

  def show
    @market = Market.find_or_initialize_by(event_id: params[:event_id].to_s)
    hydrate_market_attrs(@market)
    @market.save! if @market.new_record? || @market.changed?
    reload_market_with_associations
    backfill_resolution_criteria_if_missing(@market)
    reload_market_with_associations

    @risk_score = @market.risk_score
    clear_recoverable_scoring_fallback!(@market, @risk_score)
    reload_market_with_associations
    @risk_score = @market.risk_score

    if insufficient_market_data?(@market)
      @risk_score = nil
      render inertia: "MarketShow", props: market_show_props(risk_score: nil)
      return
    end

    if MarketFreshness.scoring_cache_valid?(@market)
      render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
    elsif @risk_score.blank? || @risk_score.computed_at.blank?
      # Full-screen loader only until we have a persisted score row to show. If we also treated
      # blocking_display_stale? here, router.visit from the evaluating page would hit #show and
      # immediately render MarketEvaluating again (infinite loop with score_result polling).
      if prefer_background_scoring?
        enqueue_supporting_jobs(@market)
        render inertia: "MarketEvaluating", props: evaluating_props(@market)
      else
        process_scoring_inline(@market)
        reload_market_with_associations
        @risk_score = @market.risk_score
        render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
      end
    else
      # Soft stale: show current score while a refresh runs in the background (or inline when forced).
      if prefer_background_scoring?
        enqueue_supporting_jobs(@market)
      else
        process_scoring_inline(@market)
        reload_market_with_associations
        @risk_score = @market.risk_score
      end
      render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] show hydration failed: #{e.message}")
    reload_market_with_associations
    @risk_score = @market.risk_score
    render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
  end

  # JSON polling for MarketEvaluating. Always 200 + JSON (no 204) so the client never depends on clocks or ?after=.
  def score_result
    market = Market.find_by(event_id: params[:event_id].to_s)
    unless market
      render json: { pending: true, error: "market_not_found" }, status: :not_found
      return
    end

    risk_score = market.risk_score

    # Pending only until a row exists (including provisional fallback). Stricter "wait for non-provisional"
    # kept HTTP polling stuck when WebSockets were blocked — ActionCable + job broadcast handle the
    # happy path; polling must still complete for any persisted score.
    if risk_score.blank? || risk_score.computed_at.blank?
      render json: { pending: true }
      return
    end

    ApiDiagnostics.record_call(service: "markets.score_result") if defined?(ApiDiagnostics)

    render json: serialize_risk_score(risk_score).merge(pending: false)
  end

  def watchlist
    render inertia: "Watchlist"
  end

  # Batch freshness for client-side watchlist (POST JSON: { event_ids: [] }).
  def digest
    ids = digest_event_ids_param
    payload = cached_markets_digest(ids)
    render json: { markets: payload }
  rescue StandardError => e
    Rails.logger.warn("[MarketsController] digest failed: #{e.class}: #{e.message}")
    render json: { markets: {} }, status: :ok
  end

  private

  def digest_event_ids_param
    raw = params[:event_ids]
    list = raw.is_a?(Array) ? raw : []
    list.map(&:to_s).uniq.first(50)
  end

  def cached_markets_digest(event_ids)
    return {} if event_ids.blank?

    cache_key = "markets_digest:v1:#{Digest::SHA256.hexdigest(event_ids.sort.join(','))}"
    Rails.cache.fetch(cache_key, expires_in: 90.seconds) do
      build_digest_entries(event_ids)
    end
  end

  def build_digest_entries(event_ids)
    markets = Market.where(event_id: event_ids).includes(:risk_score).index_by(&:event_id)
    mids = markets.values.map(&:id)
    snap_max = {}
    clar_max = {}
    if mids.any?
      snap_max = MarketDescriptionSnapshot.where(market_id: mids).group(:market_id).maximum(:snapshot_at)
      clar_max = Clarification.where(market_id: mids).group(:market_id).maximum(
        Arel.sql("COALESCE(clarifications.detected_at, clarifications.created_at)")
      )
    end

    event_ids.index_with do |eid|
      m = markets[eid]
      unless m
        {
          event_id: eid,
          missing: true
        }
      else
        s = MarketFreshness.summary(m)
        {
          event_id: eid,
          missing: false,
          last_snapshot_at: snap_max[m.id]&.iso8601,
          last_clarification_at: clar_max[m.id]&.iso8601,
          risk_score_computed_at: s[:risk_score_computed_at],
          freshness: s[:freshness],
          stale_reason: s[:stale_reason],
          blocking_display_stale: s[:blocking_display_stale],
          rules_changed_after_score: digest_rules_changed_after_score?(m),
          score_label_outdated: s[:freshness] != MarketFreshness::FRESH
        }
      end
    end
  end

  def digest_rules_changed_after_score?(market)
    score = market.risk_score
    return false unless score&.computed_at

    market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
  end

  def reload_market_with_associations
    return unless @market&.persisted?

    @market = Market.includes(:risk_score, :market_description_snapshots, :clarifications).find(@market.id)
  end

  def serialize_score_context(market)
    summary = MarketFreshness.summary(market)
    summary.merge(criteria_timeline: MarketFreshness.criteria_timeline(market))
  end

  def market_show_props(risk_score:)
    {
      market: serialize_market(@market),
      score_context: serialize_score_context(@market),
      risk_score: risk_score ? serialize_risk_score(risk_score) : nil
    }
  end

  def evaluating_props(market)
    {
      market: serialize_market(market)
    }
  end

  # Read-only API search for live dropdown. No DB writes.
  def search_results(query)
    limit = 8
    db_results = search_results_from_db(query, limit)
    return db_results if db_results.size >= limit

    gamma_results = search_results_from_gamma(query, limit)
    merge_search_results(db_results, gamma_results, limit)
  end

  def search_results_from_db(query, limit)
    Market.search(query).with_volume.limit(limit).to_a
  rescue StandardError => e
    Rails.logger.warn("[MarketsController] db search failed: #{e.class}: #{e.message}")
    []
  end

  def search_results_from_gamma(query, limit)
    client = PolymarketClient.new
    response = client.search(query)
    response["events"].to_a.first(limit).map do |event_hash|
      attrs = PolymarketEventMapper.build_event_from_search_event(event_hash)
      OpenStruct.new(attrs)
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] gamma search fallback failed: #{e.message}")
    []
  end

  def merge_search_results(primary, fallback, limit)
    deduped = {}
    (primary + fallback).each do |market|
      event_id = market.respond_to?(:event_id) ? market.event_id.to_s : ""
      next if event_id.blank? || deduped.key?(event_id)

      deduped[event_id] = market
      break if deduped.size >= limit
    end

    deduped.values
  end

  # Show flow hydration. Updates attrs from API for the selected event.
  def hydrate_market_attrs(market)
    event_id = market.event_id.to_s
    return if event_id.blank?

    cache_key = "market_hydration:event:#{event_id}"
    event = Rails.cache.read(cache_key)
    if event.present?
      ApiDiagnostics.record_call(service: "markets.hydration", cache_hit: true, deduped: true) if defined?(ApiDiagnostics)
      attrs = PolymarketEventMapper.build_event_from_search_event(event)
      market.assign_attributes(attrs) if attrs.present?
      return
    end

    client = PolymarketClient.new
    event = nil
    begin
      event = client.event(event_id)
    rescue Faraday::Error
      response = client.search(event_id)
      event = response["events"].to_a.find { |e| e["id"].to_s == event_id }
    end
    return if event.blank?

    attrs = PolymarketEventMapper.build_event_from_search_event(event)
    return if attrs.blank?

    Rails.cache.write(cache_key, event, expires_in: 60.seconds)
    ApiDiagnostics.record_call(service: "markets.hydration") if defined?(ApiDiagnostics)
    market.assign_attributes(attrs)
  end

  def enqueue_supporting_jobs(market)
    session_key = ai_session_key
    # ✅ LLM/EMBEDDINGS CALL TRIGGER — only reachable from explicit user market selection
    RiskScoreCalculationJob.perform_later(market.id, session_key: session_key)
  end

  # Question is required; criteria may be missing from Gamma — backfill before scoring.
  def insufficient_market_data?(market)
    market.event_question.to_s.strip.empty?
  end

  def process_scoring_inline(market)
    session_key = ai_session_key
    # RiskScoreCalculationJob embeds when needed (single path; avoids duplicate OpenAI calls).
    RiskScoreCalculationJob.perform_now(market.id, session_key: session_key)
    market.reload
    if market.risk_score.blank?
      RiskScorer.persist_error_fallback!(market, error: "Scoring finished without a persisted risk score")
    end
  rescue StandardError => e
    Rails.logger.warn("[MarketsController] inline scoring failed: #{e.class}: #{e.message}")
    RiskScorer.persist_error_fallback!(market, error: e) if market&.persisted?
  end

  def clear_recoverable_scoring_fallback!(market, risk_score)
    return unless market&.persisted? && risk_score
    return unless MarketFreshness.provisional_scoring_failure_for_risk_score?(risk_score)
    return unless recoverable_pgvector_quote_error?(risk_score)

    Rails.logger.info("[MarketsController] clearing recoverable Pgvector fallback for market_id=#{market.id}")
    risk_score.destroy!
    market.association(:risk_score).reset if market.association_cached?(:risk_score)
  end

  def recoverable_pgvector_quote_error?(risk_score)
    text = scoring_error_text(risk_score)
    text.include?("can't quote Pgvector::Vector") || text.include?("can't quote Pgvector::Vector".gsub("'", "’"))
  end

  def scoring_error_text(risk_score)
    metadata = risk_score.factor_metadata.is_a?(Hash) ? risk_score.factor_metadata : {}
    explanation = risk_score_meta_section(metadata, "explanation")

    [
      risk_score.has_attribute?(:confidence_note) ? risk_score[:confidence_note] : nil,
      metadata["scoring_error"],
      metadata[:scoring_error],
      explanation["confidenceNote"],
      explanation[:confidenceNote]
    ].compact.map(&:to_s).join(" ")
  end

  # Default: background jobs + MarketEvaluating (progress UI) while scoring runs; avoids long HTTP stalls.
  # Set POLYSCOPE_FORCE_INLINE_SCORING=1 to run scoring in the web process (dev/tests/debug only).
  def prefer_background_scoring?
    !truthy_env?(ENV["POLYSCOPE_FORCE_INLINE_SCORING"])
  end

  def backfill_resolution_criteria_if_missing(market)
    return unless market&.persisted?

    return if market.resolution_criteria.to_s.strip.present?

    q = market.event_question.to_s.strip
    return if q.blank?

    market.update!(resolution_criteria: "Polymarket published resolution rules for this event apply. #{q}")
  end

  def truthy_env?(value)
    %w[1 true yes on].include?(value.to_s.strip.downcase)
  end

  def ai_session_key
    (session.respond_to?(:id) ? session.id : nil).to_s.presence || request.remote_ip.to_s
  end

  # ── Serializers ──────────────────────────────────────────────────────

  def serialize_search_result(market)
    {
      event_id: market.respond_to?(:event_id) ? market.event_id : nil,
      event_question: market.respond_to?(:event_question) ? market.event_question : "Market",
      category: market.respond_to?(:category) ? market.category : nil,
      event_image: market.respond_to?(:event_image) ? market.event_image : nil,
      volume: market.respond_to?(:volume) ? market.volume : nil,
      end_date: market.respond_to?(:end_date) && market.end_date.present? ? market.end_date.to_s : nil
    }
  end

  def serialize_market(market)
    {
      id: market.id,
      event_id: market.event_id,
      event_question: market.event_question,
      category: market.category,
      event_image: market.event_image,
      volume: market.volume,
      end_date: market.end_date&.iso8601,
      resolution_criteria: market.resolution_criteria
    }
  end

  def serialize_risk_score(risk_score)
    return nil unless risk_score

    metadata = risk_score.factor_metadata.is_a?(Hash) ? risk_score.factor_metadata : {}
    explanation = risk_score_meta_section(metadata, "explanation")
    res_card = risk_score_meta_section(explanation, "resolutionCriteria")
    liquidity = risk_score_meta_section(explanation, "liquidityNote")
    factors = serialized_risk_factors_payload(metadata, explanation)

    {
      scoring_fallback: metadata["scoring_fallback"] == true || metadata[:scoring_fallback] == true,
      score: risk_score.score.to_i,
      level: risk_score.level.to_s,
      confidence_tier: risk_score.confidence_tier.to_s.presence,
      computed_at: risk_score.computed_at&.iso8601,
      summary: explanation["summary"] || explanation[:summary],
      confidence_note: explanation["confidenceNote"] || explanation[:confidenceNote],
      confidence_explanation: explanation["confidenceExplanation"] || explanation[:confidenceExplanation],
      factors: factors,
      top_risk_drivers: Array(explanation["topRiskDrivers"] || explanation[:topRiskDrivers]),
      why_not_higher_risk: Array(explanation["whyNotHigherRisk"] || explanation[:whyNotHigherRisk]),
      resolution_criteria: {
        criteriaText: res_card["criteriaText"] || res_card[:criteriaText],
        hasAmbiguity: res_card["hasAmbiguity"] == true || res_card[:hasAmbiguity] == true,
        ambiguityLevel: res_card["ambiguityLevel"] || res_card[:ambiguityLevel],
        misinterpretations: begin
          m = res_card["misinterpretations"] || res_card[:misinterpretations]
          m.is_a?(Array) ? m : nil
        end,
        overallNote: res_card["overallNote"] || res_card[:overallNote],
        sourceLabel: res_card["sourceLabel"] || res_card[:sourceLabel]
      },
      liquidity: {
        label: liquidity["label"] || liquidity[:label],
        explanation: liquidity["explanation"] || liquidity[:explanation]
      },
      data_sources_unavailable: Array(metadata["data_sources_unavailable"] || metadata[:data_sources_unavailable]),
      similar_resolved_markets: serialize_similar_resolved_markets(metadata)
    }
  end

  def serialize_similar_resolved_markets(metadata)
    meta = metadata.is_a?(Hash) ? metadata : {}
    sim = meta["similar_outcomes"]
    return [] unless sim.is_a?(Hash)

    ids = Array(sim["similar_market_ids"]).map(&:to_i).reject(&:zero?).first(12)
    return [] if ids.empty?

    scores_raw = sim["similar_scores"]
    scores_map = scores_raw.is_a?(Hash) ? scores_raw : {}
    markets_by_id = Market.where(id: ids).includes(:disputes).index_by(&:id)

    ids.filter_map do |mid|
      m = markets_by_id[mid]
      next unless m

      detail = scores_map[mid.to_s] || scores_map[mid.to_sym]
      detail = {} unless detail.is_a?(Hash)
      similarity = detail["similarity"] || detail[:similarity]

      {
        event_id: m.event_id,
        event_question: m.event_question.to_s.truncate(180),
        status: m.status,
        end_date: m.end_date&.iso8601,
        similarity: similarity.present? ? similarity.to_f.round(4) : nil,
        dispute_hint: similar_market_dispute_hint(m)
      }
    end
  end

  def similar_market_dispute_hint(market)
    disputes = market.respond_to?(:disputes) ? market.disputes.to_a : []
    return nil if disputes.empty?

    flipped = disputes.any? do |d|
      d.final_outcome.present? && d.proposed_outcome.present? && d.final_outcome.to_s != d.proposed_outcome.to_s
    end

    flipped ? "Outcome differed from the initial proposal in UMA records" : "Had UMA dispute records"
  end

  # JSONB can surface string or symbol keys; some older rows lack explanation.factors but keep breakdown.
  def risk_score_meta_section(parent, key)
    return {} unless parent.is_a?(Hash)

    child = parent[key] || parent[key.to_sym]
    child.is_a?(Hash) ? child : {}
  end

  def serialized_risk_factors_payload(metadata, explanation)
    raw = explanation["factors"] || explanation[:factors]
    raw = [] unless raw.is_a?(Array)
    normalized = raw.filter_map { |f| normalize_risk_factor_row(f) }
    return normalized if normalized.any?

    risk_factors_from_breakdown(metadata)
  end

  def normalize_risk_factor_row(f)
    return nil unless f.is_a?(Hash)

    label = f["label"] || f[:label]
    return nil if label.blank?

    {
      label: label.to_s,
      score: (f["score"] || f[:score]).to_i,
      explanation: (f["explanation"] || f[:explanation]).presence
    }
  end

  def risk_factors_from_breakdown(metadata)
    breakdown = metadata["breakdown"] || metadata[:breakdown]
    return [] unless breakdown.is_a?(Hash)

    RiskScorer::ExplanationGenerator::FACTOR_LABELS.filter_map do |factor_key, label|
      row = breakdown[factor_key.to_s] || breakdown[factor_key.to_sym] || breakdown[factor_key]
      next unless row.is_a?(Hash)

      raw_score = row["score"] || row[:score]
      next if raw_score.nil?

      { label: label, score: raw_score.to_i, explanation: nil }
    end
  end
end
