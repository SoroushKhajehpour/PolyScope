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

    @risk_score = @market.risk_score
    if insufficient_market_data?(@market)
      @risk_score = nil
      render inertia: "MarketShow", props: market_show_props(risk_score: nil)
      return
    end

    if MarketFreshness.score_fresh?(@market)
      render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
    elsif @risk_score.blank?
      if sidekiq_available?
        enqueue_supporting_jobs(@market)
        render inertia: "MarketEvaluating", props: evaluating_props(@market)
      else
        process_scoring_inline(@market)
        reload_market_with_associations
        @risk_score = @market.risk_score
        render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
      end
    elsif MarketFreshness.blocking_display_stale?(@market)
      if sidekiq_available?
        enqueue_supporting_jobs(@market)
        render inertia: "MarketEvaluating", props: evaluating_props(@market)
      else
        process_scoring_inline(@market)
        reload_market_with_associations
        @risk_score = @market.risk_score
        render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
      end
    elsif sidekiq_available?
      enqueue_supporting_jobs(@market)
      render inertia: "MarketShow", props: market_show_props(risk_score: @risk_score)
    else
      process_scoring_inline(@market)
      reload_market_with_associations
      @risk_score = @market.risk_score
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

    # Pending only until we have a persisted score. Do not use Rails.cache for a "wait" flag — in dev,
    # MemoryStore is per-process, so Puma and Sidekiq do not share it, which caused infinite pending.
    if risk_score.blank? || risk_score.computed_at.blank?
      render json: { pending: true }
      return
    end

    ApiDiagnostics.record_call(service: "markets.score_result") if defined?(ApiDiagnostics)

    render json: serialize_risk_score(risk_score).merge(pending: false)
  end

  def methodology
    render inertia: "Methodology"
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
    Rails.cache.fetch(cache_key, expires_in: 45.seconds) do
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
      market: serialize_market(market),
      score_context: serialize_score_context(market)
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

  def insufficient_market_data?(market)
    market.event_question.to_s.strip.empty? || market.resolution_criteria.to_s.strip.empty?
  end

  def process_scoring_inline(market)
    session_key = ai_session_key
    me = market.market_embedding
    MarketEmbeddingJob.perform_now(market.id, session_key: session_key) if me.blank? || me.embedding_vector.blank?
    RiskScoreCalculationJob.perform_now(market.id, session_key: session_key)
  rescue StandardError => e
    Rails.logger.warn("[MarketsController] inline scoring failed: #{e.class}: #{e.message}")
  end

  def sidekiq_available?
    return false if truthy_env?(ENV["POLYSCOPE_FORCE_INLINE_SCORING"])

    Sidekiq::ProcessSet.new.any? do |process|
      process["beat"].present? && Time.at(process["beat"].to_f) > 30.seconds.ago
    end
  rescue StandardError
    false
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
    explanation = metadata["explanation"].is_a?(Hash) ? metadata["explanation"] : {}
    factors = explanation["factors"].is_a?(Array) ? explanation["factors"] : []
    res_card = explanation["resolutionCriteria"].is_a?(Hash) ? explanation["resolutionCriteria"] : {}
    liquidity = explanation["liquidityNote"].is_a?(Hash) ? explanation["liquidityNote"] : {}

    {
      score: risk_score.score.to_i,
      level: risk_score.level.to_s,
      confidence_tier: risk_score.confidence_tier.to_s.presence,
      computed_at: risk_score.computed_at&.iso8601,
      summary: explanation["summary"],
      confidence_note: explanation["confidenceNote"],
      confidence_explanation: explanation["confidenceExplanation"],
      factors: factors.map { |f|
        { label: f["label"], score: f["score"].to_i, explanation: f["explanation"] }
      },
      top_risk_drivers: Array(explanation["topRiskDrivers"]),
      why_not_higher_risk: Array(explanation["whyNotHigherRisk"]),
      resolution_criteria: {
        criteriaText: res_card["criteriaText"],
        hasAmbiguity: res_card["hasAmbiguity"] == true,
        ambiguityLevel: res_card["ambiguityLevel"],
        misinterpretations: res_card["misinterpretations"].is_a?(Array) ? res_card["misinterpretations"] : nil,
        overallNote: res_card["overallNote"],
        sourceLabel: res_card["sourceLabel"]
      },
      liquidity: {
        label: liquidity["label"],
        explanation: liquidity["explanation"]
      },
      data_sources_unavailable: Array(metadata["data_sources_unavailable"]),
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
end
