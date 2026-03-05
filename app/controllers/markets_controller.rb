# frozen_string_literal: true

class MarketsController < ApplicationController
  VALID_RISK_LEVELS = %w[low medium high critical].freeze

  def index
    scope = Market.with_volume.includes(:risk_score).order(created_at: :desc)
    if params[:risk].in?(VALID_RISK_LEVELS)
      scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] })
    end

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    result = Market.display_events_page(scope, page: params[:page])
    @display_units = result[:display_units]
    @pagination = result[:pagination]
  end

  def live_search
    scope = Market.with_volume.includes(:risk_score).order(created_at: :desc)
    scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] }) if params[:risk].in?(VALID_RISK_LEVELS)

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    @display_units = Market.display_units_from_markets(scope.limit(8).to_a)
    render partial: "markets/live_search_results", layout: false
  end

  private

  # Search returns events => [ { markets => [...] } ]. Flatten to market hashes with event injected;
  # one DB row per market; event_id, event_question, event_image from event.
  def hydrate_from_search(query)
    client = PolymarketClient.new
    response = client.search(query)

    flattened = response["events"].to_a.flat_map do |event|
      (event["markets"] || []).reject { |m| m["closed"] == true }.map { |m| m.merge("events" => [event]) }
    end

    flattened.each do |hash|
      attrs = PolymarketSyncMapper.to_market_attributes(hash)
      next if attrs[:polymarket_id].blank?

      market = Market.find_or_initialize_by(polymarket_id: attrs[:polymarket_id])
      market.assign_attributes(attrs)
      market.save!
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] search hydration failed: #{e.message}, using local results only")
  end
end