# frozen_string_literal: true

# Faraday client for UMA Optimistic Oracle v2 subgraph (Goldsky).
# Fetches price requests / proposals for dispute rate aggregation by condition_id.
class UmaClient
  DEFAULT_SUBGRAPH_URL = "https://api.goldsky.com/api/public/project_clus2fndawbcc01w31192938i/subgraphs/polygon-managed-optimistic-oracle-v2/1.0.5/gn"

  PAGE_SIZE = 1000
  TIMEOUT_SECONDS = 8
  HISTORICAL_TTL = 24.hours

  def initialize(subgraph_url: nil)
    @subgraph_url = subgraph_url.presence || ENV.fetch("UMA_SUBGRAPH_URL", DEFAULT_SUBGRAPH_URL)
    @conn = Faraday.new(url: @subgraph_url) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  # Returns array of { condition_id: String, disputed: Boolean } for all price requests (paginated).
  # condition_id is the UMA identifier (hex); join to Market.condition_id.
  def fetch_price_requests
    cache_key = "uma:price_requests:v1"
    cached = Rails.cache.read(cache_key)
    if cached
      ApiDiagnostics.record_call(service: "uma.price_requests", cache_hit: true, deduped: true) if defined?(ApiDiagnostics)
      return cached
    end

    out = []
    skip = 0
    loop do
      page = query_price_requests(first: PAGE_SIZE, skip: skip)
      break if page.empty?

      page.each { |r| out << normalize_request(r) }
      break if page.size < PAGE_SIZE

      skip += PAGE_SIZE
    end
    Rails.cache.write(cache_key, out, expires_in: HISTORICAL_TTL)
    out
  end

  private

  def query_price_requests(first:, skip:)
    query = <<~GQL
      query PriceRequests($first: Int!, $skip: Int!) {
        priceRequests(first: $first, skip: $skip, orderBy: time, orderDirection: desc) {
          id
          identifier {
            id
          }
          proposedPrice
          resolvedPrice
          requestTimestamp
          expirationTimestamp
        }
      }
    GQL
    body = { query: query, variables: { first: first, skip: skip } }
    attempts = 0
    begin
      attempts += 1
      res = @conn.post("", body)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed
      retry if attempts < 2
      raise
    end
    if defined?(ApiDiagnostics)
      ApiDiagnostics.record_call(service: "uma.price_requests")
      ApiDiagnostics.record_rate_limit(service: "uma.price_requests", headers: res.headers.to_h)
    end
    raise "UMA subgraph error: #{res.status}" unless res.success?

    data = res.body
    list = data.dig("data", "priceRequests")
    return [] unless list.is_a?(Array)

    list
  end

  def normalize_request(row)
    identifier = row.dig("identifier", "id") || row["identifier"].to_s
    # Disputed if there was a dispute (e.g. proposedPrice != resolvedPrice and resolved); heuristic if no dispute event.
    proposed = row["proposedPrice"]
    resolved = row["resolvedPrice"]
    disputed = proposed.present? && resolved.present? && proposed.to_s != resolved.to_s
    {
      condition_id: identifier.to_s.strip.presence,
      disputed: disputed
    }.compact
  end
end
