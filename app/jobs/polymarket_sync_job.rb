# frozen_string_literal: true

class PolymarketSyncJob < ApplicationJob
  PAGE_LIMIT = 100

  def perform
    client = PolymarketClient.new
    data = client.markets(limit: PAGE_LIMIT, offset: 0, closed: false)

    data.each do |hash|
      attrs = market_attributes_from_api(hash)
      next if attrs[:polymarket_id].blank?

      market = Market.find_or_create_by!(polymarket_id: attrs[:polymarket_id])
      market.update!(attrs)
    end
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketSyncJob] #{e.message}")
    raise
  end

  private

  def market_attributes_from_api(hash)
    yes_price, no_price = parse_outcome_prices(hash["outcomePrices"])
    {
      polymarket_id: hash["id"]&.to_s,
      question: hash["question"].presence,
      resolution_criteria: hash["resolutionSource"].presence,
      category: hash["category"].presence,
      end_date: parse_time(hash["endDate"] || hash["endDateIso"]),
      status: hash["closed"] == true ? "closed" : "active",
      yes_price: yes_price,
      no_price: no_price,
      volume: parse_volume(hash["volumeNum"] || hash["volume"])
    }.compact
  end

  def parse_outcome_prices(str)
    return [nil, nil] if str.blank?

    parts = str.to_s.split(",").map { |s| s.strip.to_f }
    [parts[0], parts[1]]
  end

  def parse_time(str)
    return nil if str.blank?

    Time.zone.parse(str.to_s)
  end

  def parse_volume(val)
    return nil if val.nil?

    val.to_s.gsub(/[^\d.]/, "").to_f
  end
end
