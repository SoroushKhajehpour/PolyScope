# frozen_string_literal: true

# Orchestrates six-factor risk scoring. Commit 7: F2 full (regex + LLM when ambiguous, modifiers).
# Returns f4, f1_regex, f2_regex, f1, f2, apply_source_floor. No persistence yet.
class RiskScorer
  class << self
    # @param market [Market] Must respond to :resolution_criteria
    # @return [Hash] f4: Integer, f1_regex: Integer, f2_regex: Integer, f1: Float, f2: Integer, apply_source_floor: Boolean
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
        apply_source_floor: f2_result[:apply_source_floor]
      }
    end
  end
end
