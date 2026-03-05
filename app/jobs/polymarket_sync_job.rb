# frozen_string_literal: true

# Fetches GET /markets (and optionally search-hydration elsewhere). One DB row per API market;
# event_id, event_question, event_image come from events[0].
class PolymarketSyncJob < ApplicationJob
  PAGE_LIMIT = 100
  MAX_PAGES = 50

  def perform
    client = PolymarketClient.new
    offset = 0
    page = 0

    loop do
      break if page >= MAX_PAGES

      data = client.markets(limit: PAGE_LIMIT, offset: offset, closed: false)
      active = data.reject { |h| h["closed"] == true }

      active.each do |hash|
        attrs = PolymarketSyncMapper.to_market_attributes(hash)
        next if attrs[:polymarket_id].blank?

        market = Market.find_or_initialize_by(polymarket_id: attrs[:polymarket_id])
        market.assign_attributes(attrs)
        market.save!
      end

      break if data.size < PAGE_LIMIT

      offset += PAGE_LIMIT
      page += 1
    end
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketSyncJob] #{e.message}")
    raise
  end
end
