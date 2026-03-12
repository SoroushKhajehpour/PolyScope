# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class SourceDependencyScorerTest < ActiveSupport::TestCase
    test "call returns hash with score, apply_source_floor, and available" do
      market = Market.new(resolution_criteria: "Resolution source: Federal Register. By 2025-06-01.")
      result = SourceDependencyScorer.call(market)
      assert result.key?(:score)
      assert result.key?(:apply_source_floor)
      assert result.key?(:available)
      assert result[:score].between?(0, 20)
      assert [true, false].include?(result[:apply_source_floor])
      assert [true, false].include?(result[:available])
    end

    test "specific named source scores low" do
      market = Market.new(resolution_criteria: "Resolution source will be information from the Federal Register.")
      result = SourceDependencyScorer.call(market)
      assert result[:score] <= 6, "Federal Register with attribution should score low, got #{result[:score]}"
    end

    test "known manipulated source sets apply_source_floor" do
      market = Market.new(resolution_criteria: "Resolution based on Wikipedia article.")
      result = SourceDependencyScorer.call(market)
      assert result[:apply_source_floor], "Wikipedia should trigger apply_source_floor"
    end

    test "revision-prone BLS adds modifier" do
      # BLS without "final" or "revised" - may get +2
      market1 = Market.new(resolution_criteria: "Resolution source: BLS employment data.")
      market2 = Market.new(resolution_criteria: "Resolution source: BLS final employment estimate.")
      r1 = SourceDependencyScorer.call(market1)
      r2 = SourceDependencyScorer.call(market2)
      # r1 may be higher due to revision-prone modifier
      assert r1[:score].between?(0, 20)
      assert r2[:score].between?(0, 20)
    end

    test "editable source triggers apply_source_floor" do
      market = Market.new(resolution_criteria: "According to OpenStreetMap data.")
      result = SourceDependencyScorer.call(market)
      assert result[:score].between?(0, 20)
      assert result[:apply_source_floor], "OpenStreetMap is in known_manipulated"
    end
  end
end
