# frozen_string_literal: true

# Maps a Gamma API market hash to attributes for Market (find_or_create_by / update).
# Used by PolymarketSyncJob and by search hydration in MarketsController.
class PolymarketMarketMapper
  class << self
    def call(hash, event: nil)
      yes_price, no_price = parse_outcome_prices(hash["outcomePrices"])
      {
        polymarket_id: hash["id"]&.to_s,
        question: hash["question"].presence,
        resolution_criteria: resolution_criteria_from(hash),
        category: category_from(hash, event),
        end_date: parse_time(hash["endDate"] || hash["endDateIso"]),
        status: hash["closed"] == true ? "closed" : "active",
        yes_price: yes_price,
        no_price: no_price,
        volume: parse_volume(hash["volumeNum"] || hash["volume"]),
        image_url: image_url_from(hash, event)
      }.compact
    end

    private

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

    def resolution_criteria_from(hash)
      hash["resolutionSource"].presence || hash["description"].presence
    end

    def category_from(hash, event = nil)
      if event.present?
        from_event = event["category"].presence || first_tag_label(event["tags"])
        return from_event if from_event.present?
      end

      # Tags come from API when include_tag: true; first tag's label is the category
      tags = hash["tags"] || []
      tag_labels = tags.map { |t| t["label"]&.strip }.reject(&:blank?)
      return tag_labels.first if tag_labels.present?

      hash["category"].presence || hash.dig("events", 0, "category").presence
    end

    def first_tag_label(tags)
      return nil if tags.blank?

      tags.each do |t|
        label = t.is_a?(Hash) ? t["label"]&.strip : t.to_s.strip
        return label if label.present?
      end
      nil
    end

    def image_url_from(hash, event = nil)
      url = (event && (event["image"].presence || event["icon"].presence)) ||
            hash["image"].presence || hash["icon"].presence
      url.to_s.strip.presence
    end
  end
end
