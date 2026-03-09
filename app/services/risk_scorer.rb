# frozen_string_literal: true

# Orchestrates six-factor risk scoring. Commit 6: F1 = 0.2*regex + 0.8*llm (when LLM configured).
# Returns f4, f1_regex, f2_regex, f1 (combined ambiguity). No persistence yet.
class RiskScorer
  class << self
    # @param market [Market] Must respond to :resolution_criteria
    # @return [Hash] f4: Integer, f1_regex: Integer, f2_regex: Integer, f1: Float (0-25, combined)
    def call(market)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria : market.to_s
      f1_regex = RiskScorer::AmbiguityRegexScorer.call(text)
      f1 = RiskScorer::AmbiguityLlmScorer.call(text, regex_pre_score: f1_regex)
      {
        f4: RiskScorer::TimeSpecScorer.call(text),
        f1_regex: f1_regex,
        f2_regex: RiskScorer::SourceDependencyRegexScorer.call(text),
        f1: f1
      }
    end
  end
end
