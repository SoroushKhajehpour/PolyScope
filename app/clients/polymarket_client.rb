# frozen_string_literal: true

# =============================================================================
# Gamma API response structure (Phase 1.1 audit — from GET /markets raw payload)
# =============================================================================
#
# Response: array of market objects. No top-level wrapper. Sample in tmp/gamma_sample.json.
#
# --- Market type (Binary vs Multi-outcome vs Scalar) ---
# - No explicit "marketType" or "formatType" in the sampled payload. Type is inferred:
# - Scalar: presence of scalar range fields — scalarLow, scalarHigh (or min, max), and
#   current value in scalar (or value, currentValue). One logical market, one record.
# - Multi-outcome: a single market object whose "outcomes" field parses to an array
#   of 3+ labels (e.g. ["Trump", "Biden", "Other"]). outcomePrices has same length.
# - Binary: outcomes parses to exactly two labels (typically ["Yes", "No"]);
#   outcomePrices is a same-length array of implied probabilities.
#
# --- Outcomes representation ---
# - Top-level on each market: "outcomes" and "outcomePrices" are JSON *strings*
#   (e.g. outcomes: "[\"Yes\", \"No\"]", outcomePrices: "[\"0.137\", \"0.863\"]").
# - Parse with JSON.parse to get arrays. Index i in outcomes corresponds to index i
#   in outcomePrices (probability/price for that outcome).
# - Not nested; not multiple sibling records per outcome in the sampled /markets response.
#   Each element of the top-level array is one full market (one conditionId, one question).
#
# --- Where probability lives ---
# - Per-outcome, in outcomePrices. Same order as outcomes. Values are 0–1 implied
#   probabilities (often sum to 1 for binary).
#
# --- Scalar fields ---
# - Range: scalarLow (min), scalarHigh (max). Aliases: min, max.
# - Current price leaning: scalar, or value, or currentValue.
#
# --- Grouping / multi-outcome as N flat records ---
# - Each market has a unique conditionId (hex string). Each has an "events" array
#   (often one event); events[0].id is the parent event id. Multiple markets can
#   share the same event id (e.g. "What will happen before GTA VI?" with many
#   child markets). Those are distinct markets (different conditionId, different
#   question), not one multi-outcome market split across rows.
# - If the API elsewhere returns N flat records that share a conditionId or
#   groupId (one record per outcome), the grouping key for merging them into
#   one logical market would be that identifier (conditionId or groupId).
# - groupItemTitle / groupItemThreshold appear on binary markets under an event
#   (e.g. "Russia-Ukraine Ceasefire", "Jesus Christ returns") and label the
#   outcome within the event, not a separate multi-outcome market.
#
# =============================================================================

class PolymarketClient
  BASE_URL = "https://gamma-api.polymarket.com"

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.adapter Faraday.default_adapter
    end
  end

  def markets(limit: 100, offset: 0, closed: false, include_tag: true, order: nil, ascending: nil)
    params = { limit: limit, offset: offset, closed: closed, include_tag: include_tag }
    params[:order] = order if order.present?
    params[:ascending] = ascending unless ascending.nil?
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
      search_tags: true,
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
