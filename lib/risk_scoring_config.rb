# frozen_string_literal: true

# Loads risk scoring weights and thresholds from config/risk_scoring.yml.
# Values can be overridden by ENV: RISK_SCORING_GLOBAL_FLOOR, RISK_SCORING_PROMPT_VERSION, etc.
class RiskScoringConfig
  class << self
    def config
      @config ||= load_config
    end

    def factor_weights
      config[:factor_weights] || default_weights
    end

    def override_gates
      config[:override_gates] || default_override_gates
    end

    def global_floor
      env_int(:global_floor) || config[:global_floor] || 5
    end

    def global_ceiling
      env_int(:global_ceiling) || config[:global_ceiling] || 95
    end

    def impute_pessimistic_pct
      env_int(:impute_pessimistic_pct) || config[:impute_pessimistic_pct] || 60
    end

    def prompt_version
      ENV["RISK_SCORING_PROMPT_VERSION"].presence || config[:prompt_version] || "1.0"
    end

    def manipulation_floor_threshold
      (override_gates[:manipulation_floor_threshold] || 70).to_i
    end

    def manipulation_floor
      (override_gates[:manipulation_floor] || 65).to_i
    end

    def missing_criteria_floor
      (override_gates[:missing_criteria_floor] || 55).to_i
    end

    def known_manipulated_sources
      config[:known_manipulated_sources].to_a.map(&:to_s)
    end

    def confidence_tiers
      config[:confidence_tiers] || default_confidence_tiers
    end

    def high_confidence_min_factors
      (confidence_tiers[:high_min_factors] || 5).to_i
    end

    def high_confidence_min_age_days
      (confidence_tiers[:high_min_age_days] || 7).to_i
    end

    def medium_confidence_min_factors
      (confidence_tiers[:medium_min_factors] || 3).to_i
    end

    def low_confidence_max_age_days
      (confidence_tiers[:low_max_age_days] || 1).to_f
    end

    # Level mapping: score (0-100) → level. From config level_mapping (e.g. low: [0, 25]).
    def level_mapping
      config[:level_mapping] || default_level_mapping
    end

    def level_for_score(score)
      s = score.to_i
      level_mapping.each do |level, range|
        return level.to_s if range.is_a?(Array) && range.size >= 2 && s >= range[0] && s <= range[1]
      end
      "medium"
    end

    # Look up risk-scoring market type from Polymarket category (slug).
    # Uses fallback mapping only when LLM market type inference is unavailable.
    def market_type_for_category_slug(slug)
      mapping = fallback_market_type_mapping
      default = (mapping[:default] || "SUBJECTIVE_QUALITATIVE").to_s
      return default if slug.blank?
      key = slug.to_s.strip.downcase.parameterize.presence
      return default if key.blank?
      normalized = normalized_market_type_map(mapping)
      (normalized[key] || default).to_s
    end

    def market_type_default
      mapping = fallback_market_type_mapping
      (mapping[:default] || mapping["default"] || "SUBJECTIVE_QUALITATIVE").to_s
    end

    # @return [Hash] { market_type: String, used_default: Boolean, normalized_key: String, mapping_found: Boolean }
    def market_type_lookup(category)
      mapping = fallback_market_type_mapping
      default = market_type_default
      key = category.to_s.strip.downcase.parameterize.presence
      return { market_type: default, used_default: true, normalized_key: "", mapping_found: false } if key.blank?

      normalized = normalized_market_type_map(mapping)
      found = normalized.key?(key)
      type = found ? normalized[key].to_s : default
      { market_type: type, used_default: !found, normalized_key: key, mapping_found: found }
    end

    def reload!
      @config = nil
      config
    end

    private

    def load_config
      path = Rails.root.join("config", "risk_scoring.yml")
      return {} unless path.exist?

      yaml = YAML.load_file(path, aliases: true)
      env_key = Rails.env.to_s
      base = (yaml["default"] || {}).deep_symbolize_keys
      env = (yaml[env_key] || {}).deep_symbolize_keys
      deep_merge(base, env).deep_symbolize_keys
    end

    def normalized_market_type_map(mapping)
      mapping.each_with_object({}) do |(raw_key, raw_value), out|
        key = raw_key.to_s
        next if key == "default"
        normalized_key = key.strip.downcase.parameterize.presence
        next if normalized_key.blank?
        out[normalized_key] = raw_value.to_s
      end
    end

    def fallback_market_type_mapping
      (config[:market_type_fallback_by_category] || config[:market_type_from_category] || {}).to_h
    end

    def deep_merge(base, overrides)
      base.merge(overrides) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end

    def env_int(key)
      name = "RISK_SCORING_#{key.to_s.upcase}"
      val = ENV[name]
      val.presence && Integer(val, 10)
    rescue ArgumentError
      nil
    end

    def default_weights
      {
        f1_ambiguity: 25,
        f2_source_dep: 20,
        f3_dispute_rate: 20,
        f4_time_spec: 15,
        f5_liquidity: 10,
        f6_historical_accuracy: 10
      }
    end

    def default_override_gates
      {
        manipulation_floor_threshold: 70,
        manipulation_floor: 65,
        missing_criteria_floor: 55
      }
    end

    def default_level_mapping
      {
        low: [0, 25],
        medium: [26, 50],
        high: [51, 75],
        critical: [76, 100]
      }
    end

    def default_confidence_tiers
      {
        high_min_factors: 5,
        high_min_age_days: 7,
        medium_min_factors: 3,
        low_max_age_days: 1
      }
    end
  end
end
