# frozen_string_literal: true

# Fetches GET /markets, groups by event_id, and persists one Market row per event (no child market rows).
class PolymarketSyncJob < ApplicationJob
  PAGE_LIMIT = 100
  MAX_PAGES = 50

  def perform
    client = PolymarketClient.new
    offset = 0
    page = 0
    seen_event_ids = Set.new
    batch = []

    loop do
      break if page >= MAX_PAGES

      data = client.markets(limit: PAGE_LIMIT, offset: offset, closed: false)

      event_attrs_list = PolymarketEventMapper.build_events_from_markets(data)

      event_attrs_list.each do |attrs|
        next if attrs[:event_id].blank? || attrs[:event_question].blank?
        next if attrs[:status] == "closed"
        next if seen_event_ids.include?(attrs[:event_id])
        seen_event_ids.add(attrs[:event_id])

        now = Time.current
        batch << attrs.merge(created_at: now, updated_at: now)
      end

      break if data.size < PAGE_LIMIT

      offset += PAGE_LIMIT
      page += 1
    end

    return if batch.empty?

    Market.upsert_all(
      batch,
      unique_by: :event_id,
      update_only: %i[polymarket_id event_question event_image resolution_criteria category end_date status volume condition_id updated_at]
    )
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketSyncJob] #{e.message}")
    raise
  end
end
