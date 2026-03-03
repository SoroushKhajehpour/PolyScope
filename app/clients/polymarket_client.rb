# frozen_string_literal: true

class PolymarketClient
  BASE_URL = "https://gamma-api.polymarket.com"

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.adapter Faraday.default_adapter
    end
  end

  def markets(limit: 100, offset: 0, closed: false, include_tag: true)
    params = { limit: limit, offset: offset, closed: closed, include_tag: include_tag }
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

  # Gamma public-search: returns { "events" => [ { "markets" => [...] }, ... ] }.
  # Used to hydrate the DB with search results so pg_search can find them.
  def search(query, limit_per_type: 20)
    params = {
      q: query,
      limit_per_type: limit_per_type,
      search_tags: false,
      search_profiles: false
    }
    response = @conn.get("/public-search", params)
    raise Faraday::Error, "Gamma API returned #{response.status}" unless response.success?

    JSON.parse(response.body)
  rescue Faraday::Error => e
    Rails.logger.error("[PolymarketClient] search failed: #{e.message}")
    raise
  end
end
