# frozen_string_literal: true

# Builds one Market attribute hash per event from Gamma API data.
# Used so sync persists one row per event (no child market rows).
class PolymarketEventMapper
  class << self
    # GET /markets returns array of market hashes. Group by event_id, then build one attrs per event.
    # @param market_hashes [Array<Hash>] Raw array from client.markets
    # @return [Array<Hash>] One attribute hash per distinct event (event_id, event_question, event_image, volume, ...)
    def build_events_from_markets(market_hashes)
      return [] unless market_hashes.is_a?(Array)

      active = market_hashes.reject { |h| closed?(h) }
      grouped = active.group_by { |h| event_id_from_market(h) }
      grouped.delete_if { |eid, _| eid.blank? }

      grouped.map do |event_id, markets|
        first = markets.first
        event = first.dig("events", 0)
        total_volume = markets.sum { |m| parse_volume(m["volumeNum"] || m["volume"]) || 0 }

        {
          event_id: event_id,
          polymarket_id: event_id,
          event_question: event&.dig("title").to_s.presence,
          event_image: image_url_from(first, event),
          volume: total_volume.positive? ? total_volume : nil,
          category: category_for_event(markets, event),
          end_date: parse_time(first["endDate"] || first["endDateIso"]),
          status: markets.any? { |m| !closed?(m) } ? "active" : "closed",
          resolution_criteria: first["resolutionSource"].to_s.presence || first["description"].to_s.presence
        }.compact
      end
    end

    # Search API returns { "events" => [ event_hash, ... ] }. Build one attrs hash per event.
    # @param event_hash [Hash] Single event from response["events"]
    # @return [Hash] Attributes for one Market row, or {} if event_id missing
    def build_event_from_search_event(event_hash)
      return {} unless event_hash.is_a?(Hash)

      event_id = event_hash["id"]&.to_s.presence
      return {} if event_id.blank?

      volume = parse_volume(event_hash["volume"])
      if volume.nil? && event_hash["markets"].is_a?(Array)
        volume = event_hash["markets"].sum { |m| parse_volume(m["volume"] || m["volumeNum"]) || 0 }
      end

      first_market = event_hash["markets"]&.first
      category = category_for_event(event_hash["markets"].to_a, event_hash)
      end_date = parse_time(first_market&.dig("endDate") || first_market&.dig("endDateIso") || event_hash["endDate"])
      resolution_criteria = first_market&.dig("resolutionSource").to_s.presence || first_market&.dig("description").to_s.presence || event_hash["description"].to_s.presence

      {
        event_id: event_id,
        polymarket_id: event_id,
        event_question: event_hash["title"].to_s.presence,
        event_image: (event_hash["image"].presence || event_hash["icon"].presence).to_s.strip.presence,
        volume: volume,
        category: category,
        end_date: end_date,
        status: closed?(event_hash) ? "closed" : "active",
        resolution_criteria: resolution_criteria
      }.compact
    end

    private

    def closed?(hash)
      v = hash["closed"]
      v == true || v.to_s.casecmp?("true")
    end

    def event_id_from_market(hash)
      hash.dig("events", 0, "id")&.to_s.presence
    end

    def parse_volume(val)
      return nil if val.nil?
      Float(val)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_time(val)
      return nil if val.blank?
      Time.zone.parse(val.to_s)
    rescue ArgumentError
      nil
    end

    def category_from(hash)
      return nil unless hash.is_a?(Hash)
      tags = hash["tags"]
      return nil unless tags.is_a?(Array) && tags.first.present?
      tag_label_or_slug(tags.first)
    end

    # Tag can be { "label" => "Politics", "slug" => "politics" } or a string.
    def tag_label_or_slug(tag)
      return tag.to_s.presence if tag.is_a?(String)
      return nil unless tag.respond_to?(:[])
      (tag["label"].to_s.presence || tag["slug"].to_s.presence)
    end

    # Use the first non-nil category from any market in the group, then try event-level tags.
    def category_for_event(markets_array, event_hash)
      cat = category_from_markets(markets_array)
      return cat if cat.present?
      category_from(event_hash) if event_hash.is_a?(Hash)
    end

    # Use the first non-nil category from any market in the group/event.
    def category_from_markets(markets_array)
      return nil unless markets_array.is_a?(Array)
      markets_array.each do |m|
        cat = category_from(m)
        return cat if cat.present?
      end
      nil
    end

    def image_url_from(hash, event)
      url = (event && (event["image"].presence || event["icon"].presence)) ||
            hash["image"].presence || hash["icon"].presence
      url.to_s.strip.presence
    end
  end
end
