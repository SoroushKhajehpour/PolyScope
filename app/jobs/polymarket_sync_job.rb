# frozen_string_literal: true

class PolymarketSyncJob < ApplicationJob
  PAGE_LIMIT = 100
  MAX_PAGES = 10

  def perform
    client = PolymarketClient.new
    offset = 0
    page = 0

    loop do
      break if page >= MAX_PAGES

      data = client.markets(limit: PAGE_LIMIT, offset: offset, closed: false)

      data.each do |hash|
        attrs = PolymarketMarketMapper.call(hash)
        next if attrs[:polymarket_id].blank?

        market = Market.find_or_create_by!(polymarket_id: attrs[:polymarket_id])
        market.update!(attrs)
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
