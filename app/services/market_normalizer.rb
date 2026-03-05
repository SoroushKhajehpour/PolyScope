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
  keyword_init: true
)

class MarketNormalizer
  class << self
    # @param raw_api_response [Array<Hash>] Array of market hashes from GET /markets (or flattened from events)
    # @return [Array<MarketNormalized>] One struct per logical market (no grouping yet in 2.1)
    def call(raw_api_response)
      return [] unless raw_api_response.is_a?(Array)

      raw_api_response.filter_map { |hash| normalize_one(hash) }
    end

    private

    def normalize_one(hash)
      return nil if hash.blank?

      polymarket_id = hash["id"]&.to_s
      return nil if polymarket_id.blank?

      market_type = detect_market_type(hash)
      outcomes = build_outcomes(hash, market_type)
      group_id = hash.dig("events", 0, "id")&.to_s.presence

      MarketNormalized.new(
        polymarket_id: polymarket_id,
        group_id: group_id,
        question: hash["question"].presence,
        market_type: market_type,
        outcomes: outcomes,
        volume: parse_volume(hash["volumeNum"] || hash["volume"]),
        end_date: parse_time(hash["endDate"] || hash["endDateIso"]),
        status: hash["closed"] == true ? "closed" : "active",
        resolution_criteria: hash["resolutionSource"].presence || hash["description"].presence
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
  end
end
