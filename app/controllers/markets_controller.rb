# frozen_string_literal: true

class MarketsController < ApplicationController
  VALID_RISK_LEVELS = %w[low medium high critical].freeze

  def index
    scope = Market.includes(:risk_score).order(created_at: :desc)
    if params[:risk].in?(VALID_RISK_LEVELS)
      scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] })
    end

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    @markets = scope.page(params[:page]).per(36)
  end

  def live_search
    scope = Market.includes(:risk_score).order(created_at: :desc)
    scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] }) if params[:risk].in?(VALID_RISK_LEVELS)

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    @markets = scope.limit(8)
    render partial: "markets/live_search_results", layout: false
  end

  private

  def hydrate_from_search(query)
    client = PolymarketClient.new
    response = client.search(query)

    response["events"].to_a.each do |event|
      (event["markets"] || []).each do |market_hash|
        next if market_hash["closed"] == true # Only hydrate active markets; skip closed

        attrs = PolymarketMarketMapper.call(market_hash, event: event)
        next if attrs[:polymarket_id].blank?

        market = Market.find_or_create_by!(polymarket_id: attrs[:polymarket_id])
        market.update!(attrs)
      end
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] search hydration failed: #{e.message}, using local results only")
    # Fall back to local pg_search only; no re-raise
  end
end