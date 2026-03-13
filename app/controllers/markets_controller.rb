# frozen_string_literal: true
require "ostruct"
require "digest"

class MarketsController < ApplicationController
  def index
    # Search-first home page; live results load via /live_search.
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
    render partial: "markets/live_search_results", layout: false
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] live_search failed: #{e.message}")
    @markets = []
    render partial: "markets/live_search_results", layout: false, status: :ok
  end

  def show
    @market = Market.find_or_initialize_by(event_id: params[:event_id].to_s)
    hydrate_market_attrs(@market)
    @market.save! if @market.new_record? || @market.changed?

    @risk_score = @market.risk_score
    if insufficient_market_data?(@market)
      @risk_score = nil
      render :show
      return
    end

    if score_fresh?(@market)
      render :show
    elsif sidekiq_available?
      enqueue_supporting_jobs(@market)
      render :evaluating
    else
      process_scoring_inline(@market)
      @risk_score = @market.reload.risk_score
      render :show
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] show hydration failed: #{e.message}")
    @risk_score = @market.risk_score
    render :show
  end

  def score_result
    market = Market.find_by(event_id: params[:event_id].to_s)
    risk_score = market&.risk_score
    return head :no_content unless market && risk_score

    ApiDiagnostics.record_call(service: "markets.score_result") if defined?(ApiDiagnostics)
    render partial: "markets/risk_score_result", locals: { market: market, risk_score: risk_score }, layout: false
  end

  private

  # Read-only API search for live dropdown. No DB writes.
  def search_results(query)
    client = PolymarketClient.new
    response = client.search(query)
    response["events"].to_a.first(8).map do |event_hash|
      attrs = PolymarketEventMapper.build_event_from_search_event(event_hash)
      OpenStruct.new(attrs)
    end
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
end
