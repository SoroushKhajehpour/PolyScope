# frozen_string_literal: true

# Orchestrates six-factor risk scoring. Commit 5: regex-based factors only (F4, F1 regex, F2 regex).
# No persistence; returns hash with f4, f1_regex, f2_regex. Full composite + persistence in later commits.
class RiskScorer
  class << self
    # @param market [Market] Must respond to :resolution_criteria
    # @return [Hash] f4: Integer (0-15), f1_regex: Integer (0-25), f2_regex: Integer (0-20)
    def call(market)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria : market.to_s
      {
        f4: RiskScorer::TimeSpecScorer.call(text),
        f1_regex: RiskScorer::AmbiguityRegexScorer.call(text),
        f2_regex: RiskScorer::SourceDependencyRegexScorer.call(text)
      }
    end
  end
end
