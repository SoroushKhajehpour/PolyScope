# frozen_string_literal: true

module RiskScorer
  module DatePatterns
    # Matches any recognizable date or precise temporal reference.
    SPECIFIC_DATE_PATTERN = /
      # ISO and numeric formats
      \d{4}-\d{2}-\d{2}                                        |  # 2026-12-31
      \d{1,2}\/\d{1,2}\/\d{2,4}                                |  # 12/31/2026 or 31/12/2026
      \d{1,2}-\d{1,2}-\d{4}                                    |  # 31-12-2026

      # Written month name + day + year
      (?:january|february|march|april|may|june|july|august|
         september|october|november|december|
         jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)
      [\s.,\-]+\d{1,2}[\s.,\-]+\d{4}                           |  # December 31, 2026

      # Day + written month + year
      \d{1,2}[\s.,\-]+
      (?:january|february|march|april|may|june|july|august|
         september|october|november|december|
         jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)
      [\s.,\-]+\d{4}                                            |  # 31 December 2026

      # Month + year only
      (?:january|february|march|april|may|june|july|august|
         september|october|november|december|
         jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)
      [\s.,\-]+\d{4}                                            |  # December 2026

      # Quarters
      Q[1-4]\s*\d{4}                                            |  # Q4 2026
      \d{4}\s*Q[1-4]                                            |  # 2026 Q4
      (?:end\s+of|start\s+of|beginning\s+of|by\s+end\s+of|
         before\s+end\s+of)\s+Q[1-4]\s+\d{4}                    |  # end of Q4 2026

      # Year-only references with qualifier
      (?:end\s+of|start\s+of|beginning\s+of|by\s+end\s+of|
         before\s+end\s+of)\s+\d{4}                             |  # end of 2026

      # Time with timezone (signals precise deadline nearby)
      \d{1,2}:\d{2}\s*(?:AM|PM|am|pm)\s*(?:ET|PT|CT|MT|UTC|GMT|EST|PST|CST|MST)
    /ix.freeze

    DATE_PATTERN = SPECIFIC_DATE_PATTERN
  end
end
