# frozen_string_literal: true

# Factor 5: Clarification count (0–10). Base count, recency (0.5^(days_before_end/14)), magnitude.
# Multiply base * recency * magnitude; cap at 10.
module RiskScorer
  class ClarificationScorer
    MAX_SCORE = 10
    RECENCY_HALFLIFE_DAYS = 14

    BASE_BY_COUNT = { 0 => 0, 1 => 2, 2 => 4, 3 => 6 }.freeze
    BASE_FOR_4_PLUS = 8

    MAGNITUDE_WEIGHT = {
      "minor" => 1.0,
      "moderate" => 1.5,
      "major" => 2.0,
      "critical" => 3.0
    }.freeze

    class << self
      # @param market [Market] Must have clarifications association and end_date
      # @return [Float] 0–10
      def call(market)
        clarifications = market.respond_to?(:clarifications) ? market.clarifications.to_a : []
        base = BASE_BY_COUNT[clarifications.size] || BASE_FOR_4_PLUS
        return 0.0 if base.zero?

        end_date = market.respond_to?(:end_date) ? market.end_date : nil
        recency = max_recency(clarifications, end_date)
        magnitude = max_magnitude(clarifications)

        raw = base * recency * magnitude
        [[raw.round(2), MAX_SCORE].min, 0.0].max
      end

      private

      def max_recency(clarifications, end_date)
        return 0.5 if end_date.blank?
        clarifications.map { |c| recency_multiplier(c.detected_at, end_date) }.max || 0.5
      end

      def recency_multiplier(detected_at, end_date)
        return 0.5 if detected_at.blank?
        days_before_end = (end_date.to_time - detected_at.to_time) / 1.day
        return 0.5 if days_before_end <= 0
        0.5**(days_before_end / RECENCY_HALFLIFE_DAYS)
      end

      def max_magnitude(clarifications)
        weights = clarifications.map { |c| magnitude_weight(c) }
        weights.max || 1.0
      end

      def magnitude_weight(clarification)
        prev = clarification.previous_text.to_s
        curr = clarification.new_text.to_s
        return 1.0 if prev.blank? || curr.blank?
        result = DescriptionChangeDetector.detect(prev, curr)
        MAGNITUDE_WEIGHT[result[:magnitude].to_s] || 1.0
      end
    end
  end
end
