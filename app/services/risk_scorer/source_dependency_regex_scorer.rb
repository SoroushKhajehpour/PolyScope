# frozen_string_literal: true

# Factor 2 regex pre-score (0–20). Detects SOURCE_ATTRIBUTION, CONSENSUS_PATTERN, SPECIFIC_SOURCE.
# Tier mapping: specific named → 0–4; consensus → 9–12; vague/none → 17–20.
module RiskScorer
  class SourceDependencyRegexScorer
    MAX_SCORE = 20

    # Polymarket patterns from research
    SOURCE_ATTRIBUTION = /(?:according to|as reported by|as determined by|per|based on (?:data|information) from|as (?:published|announced|confirmed) by|resolution source (?:will be|is))\s+(.{3,100}?)(?:\.|,|;)/im
    CONSENSUS_PATTERN = /(?:consensus of (?:credible|reliable) (?:reporting|sources|media)|credible\s+reporting|major\s+English-language\s+outlets)/i
    SPECIFIC_SOURCE = /\b(?:Federal Register|BLS|Census Bureau|Fed(?:eral Reserve)?|SEC|FDA|CDC|WHO|AP|Reuters|NFL|NBA|FIFA|Chainlink)\b/i

    class << self
      def call(resolution_criteria)
        text = resolution_criteria.to_s.strip
        return MAX_SCORE if text.blank?

        has_consensus = text.match?(CONSENSUS_PATTERN)
        has_specific = text.match?(SPECIFIC_SOURCE)
        has_attribution = text.match?(SOURCE_ATTRIBUTION)

        # Tier 1 (0–4): Multiple/specific machine-verifiable sources
        return 2 if has_specific && has_attribution
        return 4 if has_specific

        # Tier 2 (5–8): Single institutional source (simplified: specific without consensus)
        return 6 if has_attribution && !has_consensus

        # Tier 3 (9–12): Consensus of credible reporting
        return 10 if has_consensus
        return 12 if has_attribution && text.match?(/credible|reliable|major\s+outlet/i)

        # Tier 4 (13–16): Vague or single media source
        return 14 if has_attribution

        # Tier 5 (17–20): No source specified
        MAX_SCORE - 2
      end
    end
  end
end
