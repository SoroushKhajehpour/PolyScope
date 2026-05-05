# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class SimilarOutcomesScorerTest < ActiveSupport::TestCase
    test "call returns hash with score, availability, and factor_metadata" do
      market = Market.new
      market.define_singleton_method(:market_embedding) { nil }
      result = SimilarOutcomesScorer.call(market)
      assert result.key?(:score)
      assert result.key?(:available)
      assert result.key?(:factor_metadata)
      assert result[:score].between?(0, 10)
      assert result[:factor_metadata].key?(:similar_market_ids)
      assert result[:factor_metadata].key?(:similar_scores)
      assert_equal false, result[:available]
    end

    test "call returns 0 when market has no embedding" do
      market = Market.new
      market.define_singleton_method(:market_embedding) { nil }
      result = SimilarOutcomesScorer.call(market)
      assert_equal 0, result[:score]
      assert_equal [], result[:factor_metadata][:similar_market_ids]
    end

    test "call returns 0 when market has embedding but no vector" do
      me = MarketEmbedding.new(embedding_model: "x", embedded_text_hash: "y", embedding_vector: nil)
      market = Market.new
      market.define_singleton_method(:market_embedding) { me }
      market.define_singleton_method(:id) { 1 }
      result = SimilarOutcomesScorer.call(market)
      assert_equal 0, result[:score]
    end

    test "nearest_same_category scope exists and filters" do
      vec = Pgvector::Vector.new([0.1] * 3072)
      rel = MarketEmbedding.nearest_same_category(vec, exclude_market_id: 0, category: "Politics", limit: 5, max_distance: 0.5)
      assert rel.is_a?(ActiveRecord::Relation)
      assert_empty rel.to_a
    end

    test "nearest_same_category accepts Pgvector.encode string (AR unknown OID loads vector as String)" do
      literal = Pgvector.encode([0.1] * 3072)
      rel = MarketEmbedding.nearest_same_category(literal, exclude_market_id: 0, category: "Politics", limit: 5, max_distance: 0.5)
      assert rel.is_a?(ActiveRecord::Relation)
      assert_empty rel.to_a
    end

    test "embedding_numeric_components parses encode string to 3072 floats" do
      literal = Pgvector.encode([0.25, -0.5] + [0.0] * 3070)
      arr = MarketEmbedding.embedding_numeric_components(literal)
      assert_equal 3072, arr.size
      assert_in_delta 0.25, arr[0], 1e-6
      assert_in_delta(-0.5, arr[1], 1e-6)
    end
  end
end
