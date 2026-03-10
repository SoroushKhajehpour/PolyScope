# frozen_string_literal: true

require "test_helper"

class RiskScorerTest < ActiveSupport::TestCase
  test "call returns hash with f1-f5, f1_regex, f2_regex, apply_source_floor" do
    market = Market.new(resolution_criteria: "Resolution source: Federal Register. By 2025-06-01.", category: nil)
    result = RiskScorer.call(market)
    assert result.key?(:f4)
    assert result.key?(:f1_regex)
    assert result.key?(:f2_regex)
    assert result.key?(:f1)
    assert result.key?(:f2)
    assert result.key?(:f3)
    assert result.key?(:f5)
    assert result.key?(:apply_source_floor)
    assert result[:f4].is_a?(Integer)
    assert result[:f1_regex].is_a?(Integer)
    assert result[:f2_regex].is_a?(Integer)
    assert result[:f1].is_a?(Numeric)
    assert result[:f2].is_a?(Integer)
    assert result[:f3].is_a?(Integer)
    assert result[:f5].is_a?(Numeric)
    assert result[:f1].between?(0, 25)
    assert result[:f2].between?(0, 20)
    assert result[:f3].between?(0, 20)
    assert result[:f5].between?(0, 10)
  end

  test "call accepts object with resolution_criteria" do
    obj = OpenStruct.new(resolution_criteria: "Soon and substantial progress.")
    result = RiskScorer.call(obj)
    assert result[:f4].between?(0, 15)
    assert result[:f1_regex].between?(0, 25)
    assert result[:f2_regex].between?(0, 20)
    assert result[:f1].between?(0, 25)
    assert result[:f2].between?(0, 20)
  end

  test "call uses string when market responds to resolution_criteria" do
    market = Market.new(resolution_criteria: "2025-03-15T12:00:00Z")
    result = RiskScorer.call(market)
    assert_equal 0, result[:f4]
  end
end
