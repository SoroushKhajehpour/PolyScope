# frozen_string_literal: true

# YAML fallback classifier for risk scoring.
# Primary classification is LLM-based in RiskScorer.resolve_market_type.
module RiskScorer
  class MarketTypeClassifier
    class << self
      # @param market [Market] Must respond to :category (from Polymarket API).
      # @return [String] One of CRYPTO_PRICE, SPORTS_OUTCOME, ELECTION_POLITICAL, MACRO_ECONOMIC, GEOPOLITICAL, SUBJECTIVE_QUALITATIVE.
      def call(market)
        category = market.respond_to?(:category) ? market.category : nil
        lookup = RiskScoringConfig.market_type_lookup(category)
        if lookup[:used_default]
          Rails.logger.warn(
            "[RiskScorer] WARNING: category '#{category}' unmapped in fallback YAML lookup — using SUBJECTIVE_QUALITATIVE default."
          )
        end
        lookup[:market_type]
      end

    end
  end
end
