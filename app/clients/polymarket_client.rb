# frozen_string_literal: true

# =============================================================================
# Gamma API structure & title bug (Phase 1.1 — from tmp/gamma_markets_raw.json,
# tmp/gamma_search_raw.json via rake polymarket:dump_raw)
# =============================================================================
#
# 1) Event vs market structure
#    - GET /markets: returns an array of market objects. Each market has an
#      "events" array (usually one element). events[0] is the parent event.
#    - GET /public-search: returns { "events" => [ ... ] }. Each event has
#      "markets" (array of child markets). So search is event-centric; /markets
#      is market-centric with embedded event via events[0].
#
# 2) Exact key for event title
#    - /markets: events[0].title  (e.g. "BitBoy convicted?" or "Next Supreme Leader of Iran?")
#    - /public-search: event.title  (same meaning)
#
# 3) Event ID, image, category
#    - Event ID: events[0].id (string, e.g. "21662") or event.id in search.
#    - Event image: events[0].image or event.image (URL string).
#    - Category: no top-level "category" on event in sampled payload; tags are
#      on the market (market.tags[].label). Can use first tag or leave category
#      from market.
#
# 4) Child question, volume, link
#    - Child question: market.question (e.g. "Will there be no new Supreme Leader...").
#    - Child volume: market.volume (string) or market.volumeNum.
#    - Link: event.slug or market.slug; Polymarket URLs use slug.
#
# 5) Where the bug is (root cause)
#    - The parent event title (events[0].title) is the correct label for the
#      card when we show one card per event. We do not store it in a dedicated
#      column. MarketNormalizer sets question from the child (hash["question"]) or
#      in merge_group as fallback from first.dig("events", 0, "title"); that
#      fallback is not persisted as event_question. The card shows @market.question,
#      so we display the child market question instead of the event title. Fix:
#      add event_id, event_question, event_image; persist events[0].title into
#      event_question and use that for the card title.
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
