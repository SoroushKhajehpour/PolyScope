# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class DisputeRateScorerTest < ActiveSupport::TestCase
    setup do
      CategoryDisputeRate.delete_all
    end

    test "call returns 0-20 integer" do
      market = Market.new(category: nil)
      score = DisputeRateScorer.call(market)
      assert score.is_a?(Integer)
      assert score.between?(0, 20)
    end

    test "lookup by normalized category slug" do
      CategoryDisputeRate.create!(
        category_slug: "politics",
        total_markets: 10,
        disputed_count: 1,
        dispute_rate_pct: 10.0
      )
      market = Market.new(category: "Politics")
      score = DisputeRateScorer.call(market)
      assert_equal 20, score
    end

    test "low dispute rate maps to low score" do
      CategoryDisputeRate.create!(
        category_slug: "crypto",
        total_markets: 100,
        disputed_count: 1,
        dispute_rate_pct: 1.0
      )
      market = Market.new(category: "crypto")
      score = DisputeRateScorer.call(market)
      assert score <= 4
    end

    test "missing category uses imputed score" do
      market = Market.new(category: nil)
      score1 = DisputeRateScorer.call(market)
      market2 = Market.new(category: "")
      score2 = DisputeRateScorer.call(market2)
      assert score1.between?(0, 20)
      assert score2.between?(0, 20)
    end

    test "unknown category uses global rate" do
      market = Market.new(category: "nonexistent-category-xyz")
      score = DisputeRateScorer.call(market)
      assert score.between?(0, 20)
    end
  end
end
