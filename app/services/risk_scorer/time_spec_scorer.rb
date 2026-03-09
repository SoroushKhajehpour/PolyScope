# frozen_string_literal: true

# Factor 4: Time specification precision. Returns 0–15 (0 = best, 15 = no time specified).
# Regex-only; no external deps. Plan: ISO datetime+TZ → 0; datetime+named TZ → 1;
# specific date → 5; month/quarter → 9; year only → 10; vague → 13; none → 15.
module RiskScorer
  class TimeSpecScorer
    MAX_SCORE = 15

    # ISO 8601 datetime with timezone offset or Z
    ISO_DATETIME_TZ = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:[+-]\d{2}:?\d{2}|Z)/i
    # Named timezone (e.g. EST, PST, UTC, GMT, EDT)
    NAMED_TZ = /\b(?:EST|EDT|CST|CDT|MST|MDT|PST|PDT|UTC|GMT|AEST|CET|CEST|IST)\b/i
    # Written date: Month DD, YYYY or DD Month YYYY
    WRITTEN_DATE = /\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}|\b\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{4}/i
    # ISO date only (no time)
    ISO_DATE = /\d{4}-\d{2}-\d{2}\b/
    # Month + year or month name only with year
    MONTH_QUARTER = /\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+\d{4}\b|\b(?:Q[1-4]|first|second|third|fourth)\s+quarter\s+(?:of\s+)?\d{4}\b/i
    # Year only
    YEAR_ONLY = /\b(?:19|20)\d{2}\b/
    # Vague temporal
    VAGUE_TIME = /\b(?:soon|shortly|recently|near\s+future|in\s+the\s+future|by\s+end\s+of\s+(?:the\s+)?year|from\s+time\s+to\s+time|periodically)\b/i

    class << self
      def call(resolution_criteria)
        text = resolution_criteria.to_s.strip
        return MAX_SCORE if text.blank?

        return 0  if text.match?(ISO_DATETIME_TZ)
        return 1  if datetime_with_named_tz?(text)
        return 5  if text.match?(WRITTEN_DATE) || text.match?(ISO_DATE)
        return 9  if text.match?(MONTH_QUARTER)
        return 10 if text.match?(YEAR_ONLY)
        return 13 if text.match?(VAGUE_TIME)

        MAX_SCORE
      end

      private

      def datetime_with_named_tz?(text)
        text.match?(NAMED_TZ) && (text.match?(WRITTEN_DATE) || text.match?(/\d{1,2}:\d{2}/) || text.match?(ISO_DATE))
      end
    end
  end
end
