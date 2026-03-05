# frozen_string_literal: true

# Step 3.2: Sync fetches raw from GET /markets, normalizes via MarketNormalizer (one struct per
# logical market; multi-outcome siblings grouped), and upserts by polymarket_id. All inner markets
# under an event are persisted with group_id so "load one outer and all inners" is queryable.
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

      normalized_list = MarketNormalizer.call(active)
      normalized_list.each do |n|
        next if n.nil? || n.polymarket_id.blank?

        attrs = MarketNormalizer.to_market_attributes(n)
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
