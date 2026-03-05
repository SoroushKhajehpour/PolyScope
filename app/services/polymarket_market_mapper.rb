# frozen_string_literal: true

# Maps a Gamma API market hash to attributes for Market (find_or_create_by / update).
# Used by PolymarketSyncJob and by search hydration in MarketsController.
#
# --- Step 1.2 findings (known bugs / gaps) ---
# - Market type is NOT inferred here. Market model infers it in before_save via detect_market_type
#   (yes_price/no_price => binary, outcomes.size > 2 => multi_outcome, min/max_value => scalar).
#   So we never set market_type in attrs; type can be wrong if outcomes/jsonb shape is wrong.
# - Outcome/probability: we set yes_price/no_price from first two outcomePrices and optionally
#   set attrs[:outcomes] from outcomes_from. outcomes_from only returns when labels.size > 2,
#   so binary markets never get outcomes jsonb set here; Market then infers binary from yes/no.
#   If API returns one record per outcome (N flat records), we'd create N Market rows with no grouping.
# - No grouping key is stored: event id (events[0].id) and conditionId are never written to Market;
#   we have no group_id column yet, so "inner" markets under one event cannot be associated.
class PolymarketMarketMapper
  class << self
    def call(hash, event: nil)
      # Outcome prices: we always take first two as yes_price, no_price. API may send JSON string
      # "[\"0.137\", \"0.863\"]" — we split on comma so we get both; no JSON.parse here so
      # we rely on comma separation. Can misclassify if outcomes string has different format.
      yes_price, no_price = parse_outcome_prices(hash["outcomePrices"])
      attrs = {
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
      }
      # outcomes jsonb only set when outcomes_from returns non-nil — i.e. when parsed outcomes
      # has > 2 labels. So binary markets never get outcomes stored by mapper; multi-outcome
      # only if a single API item has 3+ outcomes. No grouping of sibling records.
      attrs[:outcomes] = outcomes_from(hash) if outcomes_from(hash).present?
      attrs.merge!(scalar_attrs_from(hash))
      attrs.compact
    end

    private

    # Returns [yes_price, no_price] from first two values. outcomePrices can be JSON string
    # "[\"0.137\", \"0.863\"]" — we split on "," so we get two floats. Does not parse JSON.
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

    # Returns array of { "label" => String, "price" => Float } for multi-outcome markets.
    # BUG: API often sends outcomes as JSON string "[\"Yes\", \"No\"]" — we do not parse it,
    # so labels can be nil (is_a?(Array) fails). We only populate outcomes when labels.size > 2,
    # so binary markets never get outcomes jsonb; multi-outcome only if one API record has 3+.
    # If API returned N flat records (one per outcome) we'd map each to a separate Market row
    # with no grouping key stored.
    def outcomes_from(hash)
      labels = hash["outcomes"]
      labels = labels.is_a?(Array) ? labels : nil
      return nil if labels.blank?

      prices_str = hash["outcomePrices"]
      if prices_str.is_a?(Array)
        prices = prices_str.map { |p| p.to_s.strip.to_f }
      else
        prices = prices_str.to_s.split(",").map { |s| s.strip.to_f }
      end
      return nil if prices.size != labels.size || labels.size <= 2

      labels.each_with_index.map do |label, i|
        { "label" => label.to_s.strip.presence || "Option #{i + 1}", "price" => prices[i] }
      end
    end

    # Returns { min_value:, max_value:, current_value: } for scalar markets when API provides range data.
    # Gamma API may use scalarLow/scalarHigh/scalar or min/max/value.
    def scalar_attrs_from(hash)
      min = parse_decimal(hash["scalarLow"] || hash["min"])
      max = parse_decimal(hash["scalarHigh"] || hash["max"])
      current = parse_decimal(hash["scalar"] || hash["value"] || hash["currentValue"])
      return {} if min.nil? || max.nil?

      { min_value: min, max_value: max, current_value: current }.compact
    end

    def parse_decimal(val)
      return nil if val.nil? || val.to_s.strip.blank?

      val.to_s.gsub(/[^\d.-]/, "").to_f
    end
  end
end
