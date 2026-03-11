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

    # Convenience: single gate value
    def ambiguity_floor_threshold
      override_gates[:ambiguity_floor_threshold] || 22
    end

    def ambiguity_floor_score
      override_gates[:ambiguity_floor_score] || 60
    end

    def source_floor_score
      override_gates[:source_floor_score] || 50
    end

    def similar_floor_score
      override_gates[:similar_floor_score] || 50
    end

    def similar_cosine_threshold
      (override_gates[:similar_cosine_threshold] || 0.85).to_f
    end

    def known_manipulated_sources
      config[:known_manipulated_sources].to_a.map(&:to_s)
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

    def reload!
      @config = nil
      config
    end

    private

    def load_config
      path = Rails.root.join("config", "risk_scoring.yml")
      return {} unless path.exist?

      yaml = YAML.load_file(path)
      env_key = Rails.env.to_s
      base = (yaml["default"] || {}).deep_symbolize_keys
      env = (yaml[env_key] || {}).deep_symbolize_keys
      deep_merge(base, env).deep_symbolize_keys
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
        f5_clarifications: 10,
        f6_similar_outcomes: 10
      }
    end

    def default_override_gates
      {
        ambiguity_floor_threshold: 22,
        ambiguity_floor_score: 60,
        source_floor_score: 50,
        similar_floor_score: 50,
        similar_cosine_threshold: 0.85
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
  end
end
