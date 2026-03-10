# frozen_string_literal: true

# Factor 3: Category dispute rate (0–20). Lookup CategoryDisputeRate by market.category.
# If category missing, use global rate (~1.5%) or impute 60% of max.
module RiskScorer
  class DisputeRateScorer
    MAX_SCORE = 20
    GLOBAL_DISPUTE_RATE_PCT = 1.5
    MAX_DISPUTE_RATE_FOR_SCALE = 10.0 # 10% = 20 points

    class << self
      # @param market [Market] Must respond to :category
      # @return [Integer] 0–20
      def call(market)
        category = market.respond_to?(:category) ? market.category : nil
        slug = category_slug(category)

        if slug.blank?
          return impute_score
        end

        cdr = CategoryDisputeRate.find_by(category_slug: slug)
        rate_pct = cdr&.dispute_rate_pct&.to_f

        if rate_pct.nil?
          rate_pct = GLOBAL_DISPUTE_RATE_PCT
        end

        translate_to_score(rate_pct)
      end

      private

      def category_slug(category)
        return nil if category.blank?
        category.to_s.parameterize.presence
      end

      def translate_to_score(rate_pct)
        return 0 if rate_pct.nil? || rate_pct <= 0
        raw = (rate_pct / MAX_DISPUTE_RATE_FOR_SCALE) * MAX_SCORE
        [[raw.round, MAX_SCORE].min, 0].max
      end

      def impute_score
        (RiskScoringConfig.impute_pessimistic_pct.to_f / 100.0 * MAX_SCORE).round
      end
    end
  end
end
