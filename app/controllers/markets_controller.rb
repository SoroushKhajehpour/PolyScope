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

  # Step 3.2: Search returns events => [ { markets => [...] } ]. Flatten to array of market hashes
  # with event injected so normalizer can set group_id; normalize and upsert by polymarket_id.
  # All inner markets for each event are persisted (no dropping); group_id links to event.
  def hydrate_from_search(query)
    client = PolymarketClient.new
    response = client.search(query)

    flattened = response["events"].to_a.flat_map do |event|
      (event["markets"] || []).reject { |m| m["closed"] == true }.map { |m| m.merge("events" => [event]) }
    end
    normalized_list = MarketNormalizer.call(flattened)

    normalized_list.each do |n|
      next if n.nil? || n.polymarket_id.blank?

      attrs = MarketNormalizer.to_market_attributes(n)
      market = Market.find_or_initialize_by(polymarket_id: attrs[:polymarket_id])
      market.assign_attributes(attrs)
      market.save!
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] search hydration failed: #{e.message}, using local results only")
  end
end