# frozen_string_literal: true

# Normalizes raw Gamma API market hashes into a single internal representation.
# Returns one MarketNormalized per logical market (grouping of siblings in Step 2.2).
# Outcome shapes:
#   Binary:  [{ label: "Yes", probability: 0.61 }, { label: "No", probability: 0.39 }]
#   Multi:   [{ label: "Trump", probability: 0.44 }, ...]
#   Scalar: [{ label: "Current", value: 72400.0, range_min: 60000, range_max: 90000 }]
MarketNormalized = Struct.new(
  :polymarket_id,
  :group_id,
  :question,
  :market_type,
  :outcomes,
  :volume,
  :end_date,
  :status,
  :resolution_criteria,
  :category,
  :image_url,
  keyword_init: true
)

class MarketNormalizer
  class << self
    # @param raw_api_response [Array<Hash>] Array of market hashes from GET /markets (or flattened from events)
    # @return [Array<MarketNormalized>] One struct per logical market; siblings with same conditionId/groupId merged (Step 2.2)
    def call(raw_api_response)
      return [] unless raw_api_response.is_a?(Array)

      grouped = raw_api_response.group_by { |h| grouping_key(h) }
      grouped.filter_map do |_key, hashes|
        if hashes.size == 1
          normalize_one(hashes.first)
        else
          merge_group(hashes)
        end
      end
    end

    private

    def grouping_key(hash)
      hash["conditionId"].presence || hash["groupId"].presence || hash["id"]&.to_s
    end

    def merge_group(hashes)
      first = hashes.first
      condition_id = first["conditionId"].presence || first["groupId"].presence
      polymarket_id = condition_id.presence || first["id"]&.to_s
      return nil if polymarket_id.blank?

      outcomes = hashes.flat_map { |h| outcome_entries_for_merge(h) }.compact
      return nil if outcomes.empty?

      group_id = first.dig("events", 0, "id")&.to_s.presence
      question = first["question"].presence || first.dig("events", 0, "title").presence
      volume = hashes.sum { |h| parse_volume(h["volumeNum"] || h["volume"]) || 0 }
      end_date = parse_time(first["endDate"] || first["endDateIso"])
      status = hashes.any? { |h| h["closed"] != true } ? "active" : "closed"

      event = first.dig("events", 0)
      MarketNormalized.new(
        polymarket_id: polymarket_id,
        group_id: group_id,
        question: question,
        market_type: :multi_outcome,
        outcomes: outcomes,
        volume: volume.positive? ? volume : nil,
        end_date: end_date,
        status: status,
        resolution_criteria: first["resolutionSource"].presence || first["description"].presence,
        category: category_from_hash(first, event),
        image_url: image_url_from_hash(first, event)
      )
    end

    # Outcome entries from one API record when merging a group. When record has groupItemTitle (event-child),
    # treat as one outcome: label = groupItemTitle, probability = yes (first) price. When record has 3+
    # outcomes (already multi), return all. Otherwise one outcome from question + first price.
    def outcome_entries_for_merge(hash)
      labels = parse_outcomes_array(hash["outcomes"])
      prices = parse_prices_array(hash["outcomePrices"])
      # Already multi-outcome: add all
      if labels.is_a?(Array) && prices.is_a?(Array) && labels.size == prices.size && labels.size > 2
        return labels.each_with_index.map do |label, i|
          { label: label.to_s.strip.presence || "Option #{i + 1}", probability: prices[i].to_f }
        end
      end
      # One outcome per record: groupItemTitle (or question) + first (Yes) price
      label = hash["groupItemTitle"].presence || hash["question"].presence
      price = prices&.first
      return [] if label.blank? || price.nil?

      [{ label: label.to_s.strip, probability: price.to_f }]
    end

    def normalize_one(hash)
      return nil if hash.blank?

      polymarket_id = hash["id"]&.to_s
      return nil if polymarket_id.blank?

      market_type = detect_market_type(hash)
      outcomes = build_outcomes(hash, market_type)
      group_id = hash.dig("events", 0, "id")&.to_s.presence

      event = hash.dig("events", 0)
      MarketNormalized.new(
        polymarket_id: polymarket_id,
        group_id: group_id,
        question: hash["question"].presence,
        market_type: market_type,
        outcomes: outcomes,
        volume: parse_volume(hash["volumeNum"] || hash["volume"]),
        end_date: parse_time(hash["endDate"] || hash["endDateIso"]),
        status: hash["closed"] == true ? "closed" : "active",
        resolution_criteria: hash["resolutionSource"].presence || hash["description"].presence,
        category: category_from_hash(hash, event),
        image_url: image_url_from_hash(hash, event)
      )
    end

    def detect_market_type(hash)
      return :scalar if scalar?(hash)
      return :multi_outcome if multi_outcome?(hash)

      :binary
    end

    def scalar?(hash)
      min = hash["scalarLow"] || hash["min"]
      max = hash["scalarHigh"] || hash["max"]
      min.present? && max.present?
    end

    def multi_outcome?(hash)
      labels = parse_outcomes_array(hash["outcomes"])
      labels.is_a?(Array) && labels.size > 2
    end

    def build_outcomes(hash, market_type)
      case market_type
      when :scalar
        build_scalar_outcomes(hash)
      when :multi_outcome
        build_multi_outcomes(hash)
      else
        build_binary_outcomes(hash)
      end
    end

    def build_binary_outcomes(hash)
      labels = parse_outcomes_array(hash["outcomes"])
      prices = parse_prices_array(hash["outcomePrices"])
      return [] if labels.blank? || prices.blank? || labels.size != prices.size

      labels.each_with_index.map do |label, i|
        {
          label: label.to_s.strip.presence || (i.zero? ? "Yes" : "No"),
          probability: prices[i].to_f
        }
      end
    end

    def build_multi_outcomes(hash)
      labels = parse_outcomes_array(hash["outcomes"])
      prices = parse_prices_array(hash["outcomePrices"])
      return [] if labels.blank? || prices.blank? || labels.size != prices.size

      labels.each_with_index.map do |label, i|
        {
          label: label.to_s.strip.presence || "Option #{i + 1}",
          probability: prices[i].to_f
        }
      end
    end

    # Step 2.3: Scalar — one outcome with value, range_min, range_max (Phase 1: scalarLow/scalarHigh/scalar or min/max/value).
    def build_scalar_outcomes(hash)
      min = parse_decimal(hash["scalarLow"] || hash["min"])
      max = parse_decimal(hash["scalarHigh"] || hash["max"])
      value = parse_decimal(hash["scalar"] || hash["value"] || hash["currentValue"])
      return [] if min.nil? || max.nil?

      [{ label: "Current", value: value, range_min: min, range_max: max }.compact]
    end

    def parse_outcomes_array(outcomes)
      return nil if outcomes.blank?

      return outcomes if outcomes.is_a?(Array)
      return JSON.parse(outcomes) if outcomes.is_a?(String)

      nil
    rescue JSON::ParserError
      nil
    end

    def parse_prices_array(prices_str)
      return nil if prices_str.blank?

      if prices_str.is_a?(Array)
        return prices_str.map { |p| p.to_s.strip.to_f }
      end

      if prices_str.is_a?(String)
        parsed = JSON.parse(prices_str) rescue nil
        return parsed.map { |p| p.to_s.strip.to_f } if parsed.is_a?(Array)
        return prices_str.split(",").map { |s| s.strip.to_f }
      end

      nil
    end

    def parse_volume(val)
      return nil if val.nil?

      val.to_s.gsub(/[^\d.]/, "").to_f
    end

    def parse_time(str)
      return nil if str.blank?

      Time.zone.parse(str.to_s)
    end

    def parse_decimal(val)
      return nil if val.nil? || val.to_s.strip.blank?

      val.to_s.gsub(/[^\d.-]/, "").to_f
    end

    def category_from_hash(hash, event = nil)
      if event.present?
        from_event = event["category"].presence || first_tag_label(event["tags"])
        return from_event if from_event.present?
      end
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

    def image_url_from_hash(hash, event = nil)
      url = (event && (event["image"].presence || event["icon"].presence)) ||
            hash["image"].presence || hash["icon"].presence
      url.to_s.strip.presence
    end
  end

  # Maps a MarketNormalized struct to attributes for Market (upsert). Includes yes_price/no_price
  # for binary (from first two outcomes), scalar columns for scalar, and string market_type.
  def self.to_market_attributes(normalized)
    return {} if normalized.nil? || normalized.polymarket_id.blank?

    attrs = {
      polymarket_id: normalized.polymarket_id,
      group_id: normalized.group_id,
      question: normalized.question,
      market_type: normalized.market_type&.to_s,
      outcomes: normalized.outcomes,
      volume: normalized.volume,
      end_date: normalized.end_date,
      status: normalized.status,
      resolution_criteria: normalized.resolution_criteria,
      category: normalized.category,
      image_url: normalized.image_url
    }

    case normalized.market_type
    when :binary
      if normalized.outcomes.is_a?(Array) && normalized.outcomes.size >= 2
        attrs[:yes_price] = normalized.outcomes[0][:probability]
        attrs[:no_price] = normalized.outcomes[1][:probability]
      end
    when :scalar
      if normalized.outcomes.is_a?(Array) && (o = normalized.outcomes.first)
        attrs[:min_value] = o[:range_min]
        attrs[:max_value] = o[:range_max]
        attrs[:current_value] = o[:value]
      end
    end

    attrs.compact
  end
end
