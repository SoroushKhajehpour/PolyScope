# frozen_string_literal: true

# Fetches GET /markets, groups by event_id, and persists one Market row per event (no child market rows).
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

      event_attrs_list = PolymarketEventMapper.build_events_from_markets(data)

      event_attrs_list.each do |attrs|
        next if attrs[:event_id].blank? || attrs[:event_question].blank?
        next if attrs[:status] == "closed"

        market = Market.find_or_initialize_by(event_id: attrs[:event_id])
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
