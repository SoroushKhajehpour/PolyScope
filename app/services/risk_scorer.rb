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

      composite = (f1_val + f2_val + f3_val + f4_val + f5_val + f6_val).round

      factor_metadata = f6_result[:factor_metadata] || {}

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

    def confidence_tier_for(imputed_count, market)
      if imputed_count >= 3
        "low"
      elsif imputed_count >= 1
        "partial"
      else
        "full"
      end
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
