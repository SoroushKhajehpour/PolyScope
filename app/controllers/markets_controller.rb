# frozen_string_literal: true
require "ostruct"

class MarketsController < ApplicationController
  def index
    # Search-first home page; live results load via /live_search.
  end

  def live_search
    query = params[:q].to_s.strip
    @markets = query.present? ? search_results(query) : []
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
    if score_fresh?(@market)
      render :show
    else
      enqueue_supporting_jobs(@market)
      render :evaluating
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] show hydration failed: #{e.message}")
    @risk_score = @market.risk_score
    render :show
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

    client = PolymarketClient.new
    response = client.search(event_id)
    event = response["events"].to_a.find { |e| e["id"].to_s == event_id }
    if event.blank?
      event = response["events"].to_a.first
      event = nil unless event && event["id"].to_s == event_id
    end
    return if event.blank?

    attrs = PolymarketEventMapper.build_event_from_search_event(event)
    return if attrs.blank?

    market.assign_attributes(attrs)
  end

  def score_fresh?(market)
    score = market.risk_score
    return false unless score&.computed_at.present?
    return false unless score.computed_at > 4.hours.ago
    return false if market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
    return false if market.end_date.present? && market.end_date <= 24.hours.from_now

    true
  end

  def enqueue_supporting_jobs(market)
    MarketEmbeddingJob.perform_later(market.id) if market.market_embedding.blank?
    RiskScoreCalculationJob.enqueue_unique(market.id)
  end
end
