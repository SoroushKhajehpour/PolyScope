# frozen_string_literal: true

class PolymarketClient
  BASE_URL = "https://gamma-api.polymarket.com"

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.adapter Faraday.default_adapter
    end
  end

  def markets(limit: 100, offset: 0, closed: false)
    params = { limit: limit, offset: offset, closed: closed }
    response = @conn.get("/markets", params)
    raise Faraday::Error, "Gamma API returned #{response.status}" unless response.success?

    JSON.parse(response.body)
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketClient] markets failed: #{e.message}")
    raise
  end

  def market(id)
    response = @conn.get("/markets/#{id}")
    raise Faraday::Error, "Gamma API returned #{response.status}" unless response.success?

    JSON.parse(response.body)
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketClient] market(#{id}) failed: #{e.message}")
    raise
  end
end
