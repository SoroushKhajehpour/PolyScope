# frozen_string_literal: true

# Fetches UMA OOv2 subgraph data, joins to markets by condition_id, and upserts category dispute rates.
# Schedule: every 6h (see config/sidekiq.yml).
class UmaDisputeIngestJob < ApplicationJob
  queue_as :default

  def perform
    client = UmaClient.new
    requests = client.fetch_price_requests
    return if requests.empty?

    window_end = Time.current
    window_start = 1.day.ago # optional; subgraph doesn't always expose request time per page

    CategoryDisputeRateBuilder.new(
      requests: requests,
      window_start: window_start,
      window_end: window_end
    ).build
  rescue Faraday::Error => e
    Rails.logger.error("[UmaDisputeIngestJob] #{e.message}")
    raise
  end
end
