# frozen_string_literal: true

# Orchestrates six-factor risk scoring. Commit 11: composite assembly, override gates, persistence.
# Returns full result hash and persists to RiskScore.
class RiskScorer
  class << self
    # @param market [Market] Must respond to resolution_criteria, category, clarifications, end_date, market_embedding
    # @param persist [Boolean] If true (default), save to RiskScore
    # @return [Hash] score, level, f1–f6, factor_metadata, override_gate_applied, factors_imputed, etc.
    def call(market, persist: true)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria : market.to_s
      f1_regex = RiskScorer::AmbiguityRegexScorer.call(text)
      f1 = RiskScorer::AmbiguityLlmScorer.call(text, regex_pre_score: f1_regex)
      f2_result = RiskScorer::SourceDependencyScorer.call(market)
      f6_result = RiskScorer::SimilarOutcomesScorer.call(market)

      raw_factors = {
        f1: to_numeric(f1),
        f2: to_numeric(f2_result[:score]),
        f3: to_numeric(RiskScorer::DisputeRateScorer.call(market)),
        f4: to_numeric(RiskScorer::TimeSpecScorer.call(text)),
        f5: to_numeric(RiskScorer::ClarificationScorer.call(market)),
        f6: to_numeric(f6_result[:score])
      }

      weights = RiskScoringConfig.factor_weights
      factors_imputed = []
      f1_val = impute(raw_factors[:f1], weights[:f1_ambiguity], "f1_ambiguity", factors_imputed)
      f2_val = impute(raw_factors[:f2], weights[:f2_source_dep], "f2_source_dep", factors_imputed)
      f3_val = impute(raw_factors[:f3], weights[:f3_dispute_rate], "f3_dispute_rate", factors_imputed)
      f4_val = impute(raw_factors[:f4], weights[:f4_time_spec], "f4_time_spec", factors_imputed)
      f5_val = impute(raw_factors[:f5], weights[:f5_clarifications], "f5_clarifications", factors_imputed)
      f6_val = impute(raw_factors[:f6], weights[:f6_similar_outcomes], "f6_similar_outcomes", factors_imputed)

      factor_values = { f1: f1_val, f2: f2_val, f3: f3_val, f4: f4_val, f5: f5_val, f6: f6_val }
      weight_keys = { f1: :f1_ambiguity, f2: :f2_source_dep, f3: :f3_dispute_rate, f4: :f4_time_spec, f5: :f5_clarifications, f6: :f6_similar_outcomes }
      composite = composite_with_redistribution(factor_values, weight_keys, weights, factors_imputed)

      factor_metadata = (f6_result[:factor_metadata] || {}).dup

      override_gate_applied = nil
      if f1_val > RiskScoringConfig.ambiguity_floor_threshold
        composite = [composite, RiskScoringConfig.ambiguity_floor_score].max
        override_gate_applied = "ambiguity_floor"
      end
      if f2_result[:apply_source_floor]
        composite = [composite, RiskScoringConfig.source_floor_score].max
        override_gate_applied = "source_floor"
      end
      if similar_disputed_above_threshold?(factor_metadata)
        composite = [composite, RiskScoringConfig.similar_floor_score].max
        override_gate_applied = "similar_floor"
      end

      composite = composite.clamp(RiskScoringConfig.global_floor, RiskScoringConfig.global_ceiling)
      level = RiskScoringConfig.level_for_score(composite)
      confidence_tier = confidence_tier_for(factors_imputed.size, market)
      factor_metadata[:confidence_tier] = confidence_tier

      result = {
        score: composite,
        level: level,
        f4: f4_val.to_i,
        f1_regex: f1_regex,
        f2_regex: RiskScorer::SourceDependencyRegexScorer.call(text),
        f1: f1_val,
        f2: f2_val.to_i,
        f3: f3_val.to_i,
        f5: f5_val,
        f6: f6_val.to_i,
        apply_source_floor: f2_result[:apply_source_floor],
        factor_metadata: factor_metadata,
        override_gate_applied: override_gate_applied,
        factors_imputed: factors_imputed,
        confidence_tier: confidence_tier
      }

      if persist && market.respond_to?(:id) && market.id.present?
        persist_risk_score!(market, result)
      end

      result
    end

    private

    def to_numeric(val)
      return nil if val.nil?
      Float(val)
    rescue ArgumentError, TypeError
      nil
    end

    def impute(val, max, factor_name, factors_imputed)
      return val.round(2) if val.present? && max.present?
      pct = RiskScoringConfig.impute_pessimistic_pct.to_f / 100.0
      imputed = (max.to_f * pct).round(2)
      factors_imputed << factor_name
      imputed
    end

    # When all factors present: sum. When any missing: redistribute weight proportionally (composite from available only, scaled to 100).
    def composite_with_redistribution(factor_values, weight_keys, weights, factors_imputed)
      present_keys = factor_values.keys.reject { |k| factors_imputed.include?(weight_keys[k].to_s) }
      if present_keys.size == 6
        (factor_values[:f1] + factor_values[:f2] + factor_values[:f3] + factor_values[:f4] + factor_values[:f5] + factor_values[:f6]).round
      elsif present_keys.empty?
        (RiskScoringConfig.impute_pessimistic_pct.to_f / 100.0 * 100).round
      else
        sum_val = present_keys.sum { |k| factor_values[k].to_f }
        sum_max = present_keys.sum { |k| weights[weight_keys[k]].to_f }
        (sum_max.positive? ? (sum_val / sum_max * 100.0).round : 0)
      end
    end

    def similar_disputed_above_threshold?(factor_metadata)
      similar_scores = factor_metadata[:similar_scores] || {}
      threshold = RiskScoringConfig.similar_cosine_threshold
      similar_scores.each do |market_id, data|
        next unless (data[:similarity] || 0).to_f >= threshold
        other = Market.find_by(id: market_id)
        return true if other&.disputes&.any?
      end
      false
    end

    # HIGH: 5-6 factors and age ≥7d; MEDIUM: 3-4 factors or 1-7d; LOW: ≤2 factors or age < low_max_age_days.
    def confidence_tier_for(imputed_count, market)
      factor_count = 6 - imputed_count
      age_days = market_age_days(market)

      return "low" if factor_count < RiskScoringConfig.medium_confidence_min_factors || age_days < RiskScoringConfig.low_confidence_max_age_days
      return "high" if factor_count >= RiskScoringConfig.high_confidence_min_factors && age_days >= RiskScoringConfig.high_confidence_min_age_days
      "medium"
    end

    def market_age_days(market)
      return 0 unless market.respond_to?(:created_at) && market.created_at.present?
      ((Time.current - market.created_at.to_time) / 1.day).round(2)
    end

    def persist_risk_score!(market, result)
      record = RiskScore.find_or_initialize_by(market: market)
      record.assign_attributes(
        score: result[:score],
        level: result[:level],
        computed_at: Time.current,
        confidence_tier: result[:confidence_tier],
        f1_ambiguity: result[:f1]&.round,
        f2_source_dep: result[:f2],
        f3_dispute_rate: result[:f3],
        f4_time_spec: result[:f4],
        f5_clarifications: result[:f5]&.round,
        f6_similar_outcomes: result[:f6],
        factors_imputed: result[:factors_imputed] || [],
        override_gate_applied: result[:override_gate_applied],
        factor_metadata: deep_stringify_keys(result[:factor_metadata] || {}),
        factors: {
          f1: result[:f1],
          f2: result[:f2],
          f3: result[:f3],
          f4: result[:f4],
          f5: result[:f5],
          f6: result[:f6]
        }.stringify_keys
      )
      record.save!
    end

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end
  end
end
