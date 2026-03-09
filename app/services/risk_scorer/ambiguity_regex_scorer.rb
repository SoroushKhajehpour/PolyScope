# frozen_string_literal: true

# Factor 1 regex pre-score (0–25). Used at 20% weight; later combined with LLM.
# 10 pattern categories; subjective_terms 2.5×; absence of date/source/threshold +2–3.
module RiskScorer
  class AmbiguityRegexScorer
    MAX_SCORE = 25
    SUBJECTIVE_MULTIPLIER = 2.5
    ABSENCE_PENALTY_DATE = 2
    ABSENCE_PENALTY_SOURCE = 3
    ABSENCE_PENALTY_THRESHOLD = 2

    # Pattern name => [regex, weight per match]. Subjective gets multiplied by SUBJECTIVE_MULTIPLIER in scoring.
    PATTERNS = {
      subjective_terms: [/\b(?:significant(?:ly)?|substantial(?:ly)?|reasonable|appropriate(?:ly)?|adequate(?:ly)?|material(?:ly)?|meaningful(?:ly)?|considerable)\b/i, 1.0],
      hedge_modals: [/\b(?:may|might|could|would|should|can)\b(?!\s+not)/i, 0.8],
      vague_quantifiers: [/\b(?:some|many|several|various|certain|multiple|numerous|few|most)\b/i, 0.8],
      temporal_vague: [/\b(?:soon|recently|shortly|near\s+future|from\s+time\s+to\s+time|periodically)\b/i, 1.0],
      generalizations: [/\b(?:generally|typically|usually|often|normally|commonly|frequently|primarily|mainly|largely|mostly)\b/i, 0.8],
      conditional_qualifiers: [/\b(?:as\s+needed|as\s+appropriate|as\s+necessary|where\s+applicable|at\s+the\s+discretion)\b/i, 1.0],
      passive_no_agent: [/\b(?:is|are|was|were|be|been)\s+(?:deemed|determined|considered|resolved|decided)\b(?!\s+by\b)/i, 1.2],
      vague_sources: [/\b(?:credible\s+report(?:s|ing)?|reliable\s+source(?:s)?|major\s+(?:news\s+)?outlet(?:s)?|publicly\s+available|widely\s+reported)\b/i, 1.0],
      scope_vague: [/\b(?:including\s+but\s+not\s+limited\s+to|among\s+other(?:s)?|and\/or|etc\.?)\b/i, 0.8],
      epistemic_markers: [/\b(?:perhaps|possibly|probably|presumably|approximately|roughly|unclear|uncertain)\b/i, 1.2]
    }.freeze

    # Presence patterns for absence penalty (if none match, add penalty)
    HAS_DATE = /\d{4}-\d{2}-\d{2}|\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{4}\b|\b(?:19|20)\d{2}\b/i
    # Generic attribution phrases + named sources (agencies, wires, networks) + court/official-result phrases
    HAS_SOURCE = /
      \b(?:according\s+to|as\s+reported\s+by|resolution\s+source|from\s+(?:the\s+)?(?:website|site|url))\b
      |\b(?:Federal\s+Register|BLS|Census\s+Bureau|Fed(?:eral\s+Reserve)?|SEC|FDA|CDC|WHO|AP|Reuters|NBC|CNN|Fox(?:\s+News)?|CBS|ABC|NFL|NBA|FIFA|Chainlink)\b
      |\b(?:court\s+(?:records?|ruling|decision|filing|order)|official\s+(?:election\s+)?results?|election\s+results?)\b
    /ix
    HAS_THRESHOLD = /\d+(?:\.\d+)?%|\d+\s*\+\s*|\b(?:above|below|at least|at most|greater than|less than)\s+\d+/i

    class << self
      def call(resolution_criteria)
        text = resolution_criteria.to_s.strip
        return MAX_SCORE if text.blank?

        raw = 0.0
        PATTERNS.each do |name, (regex, weight)|
          count = text.scan(regex).size
          next if count.zero?
          w = (name == :subjective_terms) ? weight * SUBJECTIVE_MULTIPLIER : weight
          raw += count * w
        end

        raw += ABSENCE_PENALTY_DATE    unless text.match?(HAS_DATE)
        raw += ABSENCE_PENALTY_SOURCE  unless text.match?(HAS_SOURCE)
        raw += ABSENCE_PENALTY_THRESHOLD unless text.match?(HAS_THRESHOLD)

        [[raw.round, MAX_SCORE].min, 0].max
      end
    end
  end
end
