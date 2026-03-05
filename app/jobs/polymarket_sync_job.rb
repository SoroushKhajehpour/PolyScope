# frozen_string_literal: true

# Step 1.2: Sync fetches a flat array from GET /markets. Each element is one market (possibly an
# "inner" market under an event). We do not infer or set market_type here; we do not store event id
# or group_id, so inner markets (e.g. 4 markets sharing events[0].id "23784") are stored as
# separate Market rows with no link to the parent event. When one "outer" (event) is conceptually
# loaded, the API already returns all inner markets in the same page; we persist each by
# polymarket_id only — no grouping, so UI cannot "load one outer and all inners" by relationship.
class PolymarketSyncJob < ApplicationJob
  PAGE_LIMIT = 100
  MAX_PAGES = 50

  def perform
    client = PolymarketClient.new
    offset = 0
    page = 0

    loop do
      break if page >= MAX_PAGES

      # Raw response: array of market hashes. Some items share the same events[0].id (inner markets
      # under one event). We do not group by event; we process each hash as a separate Market.
      data = client.markets(limit: PAGE_LIMIT, offset: offset, closed: false, order: "volume_24hr", ascending: false)

      data.each do |hash|
        next if hash["closed"] == true # Only pull in active markets; ignore closed even if API returns them

        # One API record => one attrs hash => one Market row. No grouping; event id not stored.
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
