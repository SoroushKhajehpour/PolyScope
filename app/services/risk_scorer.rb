# frozen_string_literal: true

# Orchestrates six-factor risk scoring. Commit 8: F3, F5 added.
# Returns f1–f5, f1_regex, f2_regex, apply_source_floor. No persistence yet.
class RiskScorer
  class << self
    # @param market [Market] Must respond to :resolution_criteria, :category, :clarifications, :end_date
    # @return [Hash] f1–f5, f1_regex, f2_regex, apply_source_floor
    def call(market)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria : market.to_s
      f1_regex = RiskScorer::AmbiguityRegexScorer.call(text)
      f1 = RiskScorer::AmbiguityLlmScorer.call(text, regex_pre_score: f1_regex)
      f2_result = RiskScorer::SourceDependencyScorer.call(market)

      {
        f4: RiskScorer::TimeSpecScorer.call(text),
        f1_regex: f1_regex,
        f2_regex: RiskScorer::SourceDependencyRegexScorer.call(text),
        f1: f1,
        f2: f2_result[:score],
        apply_source_floor: f2_result[:apply_source_floor],
        f3: RiskScorer::DisputeRateScorer.call(market),
        f5: RiskScorer::ClarificationScorer.call(market)
      }
    end
  end
end
