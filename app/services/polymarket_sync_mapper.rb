# frozen_string_literal: true

# Maps one Gamma API market hash to Market attributes. One DB row per API market.
# Fills event_id, event_question, event_image from events[0] (see client comment block).
class PolymarketSyncMapper
  class << self
    # @param hash [Hash] Single market from GET /markets or from flattened search (with "events" => [event])
    # @return [Hash] Attributes for Market.find_or_initialize_by(polymarket_id:).assign_attributes(...)
    def to_market_attributes(hash)
      return {} if hash.blank?

      polymarket_id = hash["id"]&.to_s.presence
      return {} if polymarket_id.blank?

      event = hash.dig("events", 0)
      event_id = event&.dig("id")&.to_s.presence
      event_question = event&.dig("title").to_s.presence
      event_image = image_url_from(hash, event)

      volume = parse_volume(hash["volumeNum"] || hash["volume"])
      end_time = parse_time(hash["endDate"] || hash["endDateIso"])
      status = hash["closed"] == true ? "closed" : "active"
      category = category_from(hash, event)

      {
        polymarket_id: polymarket_id,
        question: hash["question"].to_s.presence,
        resolution_criteria: hash["resolutionSource"].to_s.presence || hash["description"].to_s.presence,
        category: category,
        end_date: end_time,
        status: status,
        volume: volume,
        event_id: event_id,
        event_question: event_question,
        event_image: event_image
      }.compact
    end

    private

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

    def category_from(hash, event)
      tags = hash["tags"]
      return nil unless tags.is_a?(Array) && tags.first.present?
      tags.first["label"].to_s.presence
    end

    def image_url_from(hash, event)
      url = (event && (event["image"].presence || event["icon"].presence)) ||
            hash["image"].presence || hash["icon"].presence
      url.to_s.strip.presence
    end
  end
end
