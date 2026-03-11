# frozen_string_literal: true

require "test_helper"

class RiskScorerTest < ActiveSupport::TestCase
  test "call returns hash with score, level, f1-f6, factor_metadata, override_gate_applied, confidence_tier" do
    market = Market.new(resolution_criteria: "Resolution source: Federal Register. By 2025-06-01.", category: nil)
    result = RiskScorer.call(market, persist: false)
    assert result.key?(:score)
    assert result.key?(:level)
    assert result[:score].between?(0, 100)
    assert %w[low medium high critical].include?(result[:level])
    assert result.key?(:f4)
    assert result.key?(:f1)
    assert result.key?(:f2)
    assert result.key?(:f3)
    assert result.key?(:f5)
    assert result.key?(:f6)
    assert result.key?(:factor_metadata)
    assert result.key?(:factors_imputed)
    assert result.key?(:confidence_tier)
    assert result[:factor_metadata].key?(:similar_market_ids)
    assert result[:factor_metadata].key?(:similar_scores)
  end

  test "call accepts object with resolution_criteria" do
    obj = OpenStruct.new(resolution_criteria: "Soon and substantial progress.", market_embedding: nil)
    result = RiskScorer.call(obj, persist: false)
    assert result[:score].between?(0, 100)
    assert result[:f4].between?(0, 15)
    assert result[:f1].between?(0, 25)
    assert result[:f6].between?(0, 10)
  end

  test "call uses string when market responds to resolution_criteria" do
    market = Market.new(resolution_criteria: "2025-03-15T12:00:00Z")
    result = RiskScorer.call(market, persist: false)
    assert_equal 0, result[:f4]
  end

  test "call persists RiskScore when market has id and persist true" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )
    result = RiskScorer.call(market, persist: true)
    record = RiskScore.find_by(market: market)
    assert record
    assert_equal result[:score], record.score
    assert_equal result[:level], record.level
    assert record.computed_at.present?
    assert record.factor_metadata.is_a?(Hash)
  end

  test "score is clamped to global floor and ceiling" do
    market = Market.new(resolution_criteria: "Clear date.", category: nil)
    result = RiskScorer.call(market, persist: false)
    assert result[:score] >= 5, "score should be at least global_floor 5"
    assert result[:score] <= 95, "score should be at most global_ceiling 95"
  end
end
