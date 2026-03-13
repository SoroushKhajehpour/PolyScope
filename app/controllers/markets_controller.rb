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

    @risk_score = @market.risk_score
    if insufficient_market_data?(@market)
      @risk_score = nil
      render inertia: "MarketShow", props: {
        market: serialize_market(@market),
        risk_score: nil
      }
      return
    end

    if score_fresh?(@market)
      render inertia: "MarketShow", props: {
        market: serialize_market(@market),
        risk_score: serialize_risk_score(@risk_score)
      }
    elsif sidekiq_available?
      enqueue_supporting_jobs(@market)
      render inertia: "MarketEvaluating", props: {
        market: serialize_market(@market)
      }
    else
      process_scoring_inline(@market)
      @risk_score = @market.reload.risk_score
      render inertia: "MarketShow", props: {
        market: serialize_market(@market),
        risk_score: serialize_risk_score(@risk_score)
      }
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] show hydration failed: #{e.message}")
    @risk_score = @market.risk_score
    render inertia: "MarketShow", props: {
      market: serialize_market(@market),
      risk_score: serialize_risk_score(@risk_score)
    }
  end

  def score_result
    market = Market.find_by(event_id: params[:event_id].to_s)
    risk_score = market&.risk_score
    return head :no_content unless market && risk_score && score_fresh?(market)

    ApiDiagnostics.record_call(service: "markets.score_result") if defined?(ApiDiagnostics)

    render json: serialize_risk_score(risk_score)
  end

  private

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

  def score_fresh?(market)
    score = market.risk_score
    return false unless score&.computed_at.present?
    return false unless score.computed_at > 4.hours.ago
    return false if market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
    return false if market.end_date.present? && market.end_date <= 24.hours.from_now

    # Re-score if previous result was a fallback and the LLM is now available
    metadata = score.factor_metadata
    if metadata.is_a?(Hash)
      resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
      if resolution.is_a?(Hash) && (resolution["from_fallback"] == true || resolution[:from_fallback] == true)
        return false if LlmClient.new.configured?
      end
    end

    true
  end

  def enqueue_supporting_jobs(market)
    session_key = ai_session_key
    # ✅ LLM/EMBEDDINGS CALL TRIGGER — only reachable from explicit user market selection
    # Do not move or duplicate this call elsewhere.
    MarketEmbeddingJob.perform_later(market.id, session_key: session_key) if market.market_embedding.blank?
    RiskScoreCalculationJob.enqueue_unique(market.id, session_key: session_key)
  end

  def insufficient_market_data?(market)
    market.event_question.to_s.strip.empty? || market.resolution_criteria.to_s.strip.empty?
  end

  def process_scoring_inline(market)
    session_key = ai_session_key
    MarketEmbeddingJob.perform_now(market.id, session_key: session_key) if market.market_embedding.blank?
    RiskScoreCalculationJob.perform_now(market.id, session_key: session_key)
  rescue StandardError => e
    Rails.logger.warn("[MarketsController] inline scoring failed: #{e.class}: #{e.message}")
  end

  def sidekiq_available?
    Sidekiq::ProcessSet.new.any? do |process|
      process["beat"].present? && Time.at(process["beat"].to_f) > 30.seconds.ago
    end
  rescue StandardError
    false
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
      data_sources_unavailable: Array(metadata["data_sources_unavailable"])
    }
  end
end
