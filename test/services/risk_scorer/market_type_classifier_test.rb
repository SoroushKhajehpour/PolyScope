# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class MarketTypeClassifierTest < ActiveSupport::TestCase
    test "all observed fixture/test categories are mapped to non-default type" do
      observed_categories = %w[
        Crypto Sports Politics Society World General Sci MyString
      ]
      default_type = RiskScoringConfig.market_type_default

      observed_categories.each do |category|
        lookup = RiskScoringConfig.market_type_lookup(category)
        assert lookup[:mapping_found], "expected '#{category}' to be mapped"
        refute_equal default_type, lookup[:market_type], "expected '#{category}' to map to non-default type"
      end
    end

    test "crypto and sports base resolution clarity do not exceed 20" do
      market = Market.new(resolution_criteria: "Resolved by official source on 2026-12-31")
      crypto_base = RiskScorer.send(:resolution_clarity_components, market, "CRYPTO_PRICE", "HIGH", { ambiguityLevel: "NONE" })[:base]
      sports_base = RiskScorer.send(:resolution_clarity_components, market, "SPORTS_OUTCOME", "HIGH", { ambiguityLevel: "NONE" })[:base]

      assert_operator crypto_base, :<=, 20
      assert_operator sports_base, :<=, 20
    end

    test "warns when category falls back to default mapping" do
      market = Market.new(category: "", resolution_criteria: "Resolved by official source.")
      logger = Minitest::Mock.new
      logger.expect(:warn, nil, [String])

      Rails.stub(:logger, logger) do
        type = RiskScorer::MarketTypeClassifier.call(market)
        assert_equal "SUBJECTIVE_QUALITATIVE", type
      end

      assert logger.verify
    end
  end
end
