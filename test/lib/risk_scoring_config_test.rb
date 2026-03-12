# frozen_string_literal: true

require "test_helper"

class RiskScoringConfigTest < ActiveSupport::TestCase
  setup do
    RiskScoringConfig.reload!
  end

  test "factor_weights returns legacy config hash with f1 through f6 and sum to 100" do
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
    assert_equal 70, gates[:manipulation_floor_threshold]
    assert_equal 65, gates[:manipulation_floor]
    assert_equal 55, gates[:missing_criteria_floor]
  end

  test "global_floor and global_ceiling are numeric" do
    assert_equal 5, RiskScoringConfig.global_floor
    assert_equal 95, RiskScoringConfig.global_ceiling
  end

  test "impute_pessimistic_pct falls back to numeric default when removed from yaml" do
    assert_equal 60, RiskScoringConfig.impute_pessimistic_pct
  end

  test "prompt_version returns string" do
    assert RiskScoringConfig.prompt_version.is_a?(String)
    assert RiskScoringConfig.prompt_version.present?
  end

  test "known_manipulated_sources returns array" do
    sources = RiskScoringConfig.known_manipulated_sources
    assert sources.is_a?(Array)
    assert_includes sources, "Wikipedia"
    assert_includes sources, "OpenStreetMap"
  end

  test "convenience gate accessors return expected values" do
    assert_equal 70, RiskScoringConfig.manipulation_floor_threshold
    assert_equal 65, RiskScoringConfig.manipulation_floor
    assert_equal 55, RiskScoringConfig.missing_criteria_floor
  end

  test "level_for_score returns level from config mapping" do
    assert_equal "low", RiskScoringConfig.level_for_score(0)
    assert_equal "low", RiskScoringConfig.level_for_score(25)
    assert_equal "medium", RiskScoringConfig.level_for_score(26)
    assert_equal "medium", RiskScoringConfig.level_for_score(50)
    assert_equal "high", RiskScoringConfig.level_for_score(51)
    assert_equal "high", RiskScoringConfig.level_for_score(75)
    assert_equal "critical", RiskScoringConfig.level_for_score(76)
    assert_equal "critical", RiskScoringConfig.level_for_score(100)
  end

  test "confidence_tiers returns expected keys" do
    tiers = RiskScoringConfig.confidence_tiers
    assert tiers.key?(:high_min_factors)
    assert tiers.key?(:high_min_age_days)
    assert_equal 5, RiskScoringConfig.high_confidence_min_factors
    assert_equal 7, RiskScoringConfig.high_confidence_min_age_days
    assert_equal 3, RiskScoringConfig.medium_confidence_min_factors
    assert_equal 1, RiskScoringConfig.low_confidence_max_age_days
  end

  test "market type lookup normalizes category labels and supports defaults" do
    lookup = RiskScoringConfig.market_type_lookup("Foreign Policy")
    assert_equal "GEOPOLITICAL", lookup[:market_type]
    refute lookup[:used_default]

    missing = RiskScoringConfig.market_type_lookup("totally-unknown-cat")
    assert_equal "SUBJECTIVE_QUALITATIVE", missing[:market_type]
    assert missing[:used_default]
  end
end
