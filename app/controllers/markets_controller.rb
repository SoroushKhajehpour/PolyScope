# frozen_string_literal: true

class MarketsController < ApplicationController
  VALID_RISK_LEVELS = %w[low medium high critical].freeze

  def index
    scope = Market.with_volume.includes(:risk_score).order(created_at: :desc)
    scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] }) if params[:risk].in?(VALID_RISK_LEVELS)

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    @markets = scope.page(params[:page]).per(36)
    @pagination = {
      total_pages: @markets.total_pages,
      current_page: @markets.current_page,
      prev_page: @markets.prev_page,
      next_page: @markets.next_page
    }
  end

  def live_search
    scope = Market.with_volume.includes(:risk_score).order(created_at: :desc)
    scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] }) if params[:risk].in?(VALID_RISK_LEVELS)

    if params[:q].present?
      hydrate_from_search(params[:q])
      scope = scope.search(params[:q])
    end

    @markets = scope.limit(8).to_a
    render partial: "markets/live_search_results", layout: false
  end

  private

  # Search returns events => [ { id, title, image, volume, markets => [...] } ]. Persist one Market per event.
  def hydrate_from_search(query)
    client = PolymarketClient.new
    response = client.search(query)

    response["events"].to_a.each do |event_hash|
      attrs = PolymarketEventMapper.build_event_from_search_event(event_hash)
      next if attrs[:event_id].blank? || attrs[:event_question].blank?

      market = Market.find_or_initialize_by(event_id: attrs[:event_id])
      market.assign_attributes(attrs)
      market.save!
    end
  rescue Faraday::Error => e
    Rails.logger.warn("[MarketsController] search hydration failed: #{e.message}, using local results only")
  end
end