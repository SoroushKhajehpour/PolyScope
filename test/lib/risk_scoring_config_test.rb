# frozen_string_literal: true

require "test_helper"

class RiskScoringConfigTest < ActiveSupport::TestCase
  setup do
    RiskScoringConfig.reload!
  end

  test "factor_weights returns hash with f1 through f6 and sum to 100" do
    weights = RiskScoringConfig.factor_weights
    assert weights.is_a?(Hash)
    assert_equal 25, weights[:f1_ambiguity]
    assert_equal 20, weights[:f2_source_dep]
    assert_equal 20, weights[:f3_dispute_rate]
    assert_equal 15, weights[:f4_time_spec]
    assert_equal 10, weights[:f5_clarifications]
    assert_equal 10, weights[:f6_similar_outcomes]
    assert_equal 100, weights.values.sum
  end

  test "override_gates returns expected thresholds" do
    gates = RiskScoringConfig.override_gates
    assert_equal 22, gates[:ambiguity_floor_threshold]
    assert_equal 60, gates[:ambiguity_floor_score]
    assert_equal 50, gates[:source_floor_score]
    assert_equal 50, gates[:similar_floor_score]
  end

  test "global_floor and global_ceiling are numeric" do
    assert_equal 5, RiskScoringConfig.global_floor
    assert_equal 95, RiskScoringConfig.global_ceiling
  end

  test "impute_pessimistic_pct is numeric" do
    assert_equal 60, RiskScoringConfig.impute_pessimistic_pct
  end

  test "prompt_version returns string" do
    assert RiskScoringConfig.prompt_version.is_a?(String)
    assert RiskScoringConfig.prompt_version.present?
  end

  test "convenience gate accessors return expected values" do
    assert_equal 22, RiskScoringConfig.ambiguity_floor_threshold
    assert_equal 60, RiskScoringConfig.ambiguity_floor_score
    assert_equal 50, RiskScoringConfig.source_floor_score
    assert_equal 50, RiskScoringConfig.similar_floor_score
    assert_in_delta 0.85, RiskScoringConfig.similar_cosine_threshold, 0.001
  end
end
