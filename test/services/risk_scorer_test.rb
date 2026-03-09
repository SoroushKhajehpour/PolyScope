# frozen_string_literal: true

require "test_helper"

class RiskScorerTest < ActiveSupport::TestCase
  test "call returns hash with f4, f1_regex, f2_regex, f1" do
    market = Market.new(resolution_criteria: "Resolution source: Federal Register. By 2025-06-01.")
    result = RiskScorer.call(market)
    assert result.key?(:f4)
    assert result.key?(:f1_regex)
    assert result.key?(:f2_regex)
    assert result.key?(:f1)
    assert result[:f4].is_a?(Integer)
    assert result[:f1_regex].is_a?(Integer)
    assert result[:f2_regex].is_a?(Integer)
    assert result[:f1].is_a?(Numeric)
    assert result[:f1].between?(0, 25)
  end

  test "call accepts object with resolution_criteria" do
    obj = OpenStruct.new(resolution_criteria: "Soon and substantial progress.")
    result = RiskScorer.call(obj)
    assert result[:f4].between?(0, 15)
    assert result[:f1_regex].between?(0, 25)
    assert result[:f2_regex].between?(0, 20)
    assert result[:f1].between?(0, 25)
  end

  test "call uses string when market responds to resolution_criteria" do
    market = Market.new(resolution_criteria: "2025-03-15T12:00:00Z")
    result = RiskScorer.call(market)
    assert_equal 0, result[:f4]
  end
end
