# frozen_string_literal: true

require "test_helper"

class RiskScorerTest < ActiveSupport::TestCase
  test "call returns score, level, factors, liquidity_risk and explanation metadata" do
    market = Market.new(resolution_criteria: "Resolution source: Federal Register. By 2025-06-01.", category: nil)
    result = RiskScorer.call(market, persist: false)
    assert result.key?(:score)
    assert result.key?(:level)
    assert result[:score].between?(0, 100)
    assert %w[low medium high].include?(result[:level])
    assert result.key?(:factors)
    assert result.key?(:liquidity_risk)
    assert result.key?(:factor_metadata)
    assert result.key?(:confidence_tier)
    assert result[:factors].key?(:resolution_clarity)
    assert result[:factors].key?(:time_horizon)
    assert result[:factors].key?(:historical_accuracy)
    assert result[:factors].key?(:manipulation_risk)
    assert result[:factors].key?(:information_asymmetry)
    assert result[:factor_metadata].key?(:market_type)
    assert result[:factor_metadata].key?(:breakdown)
    assert result[:factor_metadata].key?(:explanation)
    assert result[:factor_metadata].key?(:resolution_analysis)
    assert %w[high medium low].include?(result[:confidence_tier])
  end

  test "call accepts object with resolution_criteria" do
    obj = OpenStruct.new(resolution_criteria: "Soon and substantial progress.", market_embedding: nil)
    result = RiskScorer.call(obj, persist: false)
    assert result[:score].between?(0, 100)
    assert result[:factors][:historical_accuracy].between?(0, 100)
    assert result[:factors][:resolution_clarity].between?(0, 100)
    assert result[:factors][:information_asymmetry].between?(0, 100)
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
    assert %w[low medium high].include?(record.level)
    assert record.computed_at.present?
    assert record.factor_metadata.is_a?(Hash)
  end

  test "score is clamped to 0..100" do
    market = Market.new(resolution_criteria: "Clear date.", category: nil)
    result = RiskScorer.call(market, persist: false)
    assert result[:score] >= 0
    assert result[:score] <= 100
  end

  test "confidence_tier high when market is old and has enough factors" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source. By 2025-06-01.",
      created_at: 10.days.ago
    )
    result = RiskScorer.call(market, persist: false)
    assert %w[high medium low].include?(result[:confidence_tier])
  end

  test "factor_metadata exposes explanation summary" do
    market = Market.new(resolution_criteria: "Federal Register. 2025-06-01.", category: nil)
    result = RiskScorer.call(market, persist: false)
    assert result[:factor_metadata].dig(:explanation, :summary).present?
  end

  test "factor name map aligns with legacy db columns" do
    db_column_names = RiskScore.column_names.grep(/\Af[1-6]_./).map(&:to_sym).sort
    assert_equal db_column_names, RiskScorer::FACTOR_NAME_MAP.values.sort
  end
end
