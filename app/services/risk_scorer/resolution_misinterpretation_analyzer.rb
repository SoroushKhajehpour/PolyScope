# frozen_string_literal: true

require "digest"
require "json"

module RiskScorer
  class ResolutionMisinterpretationAnalyzer
    MISINTERPRETATION_CACHE_TTL = 24.hours
    VAGUE_TIME_HINT = /\b(?:before|after|by|prior to)\b(?!\s+\w*\d{4}|\s+\d{1,2}\s+\w|\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))/i

    class << self
      # ✅ LLM/EMBEDDINGS CALL TRIGGER — only reachable from explicit user market selection
      # Do not move or duplicate this call elsewhere.
      def call(market, session_key: nil)
        criteria_text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s.strip : ""
        market_title = if market.respond_to?(:event_question) && market.event_question.present?
          market.event_question.to_s
        elsif market.respond_to?(:title) && market.title.present?
          market.title.to_s
        else
          "Unknown market"
        end
        category_label = market.respond_to?(:category) ? market.category.to_s : ""
        cache_key = build_cache_key(market_title, criteria_text)

        cached = Rails.cache.read(cache_key)
        if cached.present?
          symbolized = cached.deep_symbolize_keys
          # Don't serve cached fallback if LLM is now available — re-score with real analysis
          unless symbolized[:from_fallback] && LlmClient.new.configured?
            return symbolized
          end
        end

        if criteria_text.blank?
          result = no_criteria_result
          Rails.cache.write(cache_key, result, expires_in: MISINTERPRETATION_CACHE_TTL)
          return result
        end

        dedupe_key = "misinterpretation:#{cache_key}"
        # Use `next`, never `return`, inside this block — `return` skips AiCallGovernor lock cleanup.
        RiskScorer::AiCallGovernor.with_dedup_lock(dedupe_key) do
          cached_again = Rails.cache.read(cache_key)
          if cached_again.present?
            symbolized_again = cached_again.deep_symbolize_keys
            next symbolized_again unless symbolized_again[:from_fallback] && LlmClient.new.configured?
          end

          budget = RiskScorer::AiCallGovernor.acquire_budget(provider: "anthropic", session_key: session_key)
          unless budget[:allowed]
            fallback = fallback_misinterpretation_analysis(criteria_text).merge(
              from_fallback: true,
              fallback_reason: budget[:reason]
            )
            Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL)
            next fallback
          end

          client = LlmClient.new
          unless client.configured?
            fallback = fallback_misinterpretation_analysis(criteria_text).merge(from_fallback: true)
            Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL)
            next fallback
          end

          result = client.chat(
            system: system_prompt,
            user: user_prompt(criteria_text, market_title, category_label),
            temperature: 0.1,
            model: nil
          )

          if result.blank?
            fallback = fallback_misinterpretation_analysis(criteria_text).merge(from_fallback: true)
            Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL)
            next fallback
          end

          parsed = normalize_response(result)
          Rails.cache.write(cache_key, parsed, expires_in: MISINTERPRETATION_CACHE_TTL)
          ApiDiagnostics.record_call(service: "anthropic.misinterpretation") if defined?(ApiDiagnostics)
          parsed
        end
      rescue StandardError => e
        Rails.logger.error(
          "[ResolutionMisinterpretationAnalyzer] #{e.class}: #{e.message}\n#{Array(e.backtrace).first(12).join("\n")}"
        )
        fallback = fallback_misinterpretation_analysis(criteria_text).merge(from_fallback: true)
        Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL) if cache_key.present?
        fallback
      end

      def fallback_misinterpretation_analysis(criteria_text)
        text = criteria_text.to_s
        issues = []

        if text.match?(/admin|discretion|determine|decide/i)
          issues << {
            issue: "Resolver discretion",
            description: "The criteria gives the resolver discretionary power to decide the outcome, which could lead to disputed rulings.",
            affectedPhrase: text.match(/admin|discretion|determine|decide/i)&.to_s
          }
        end

        if text.match?(VAGUE_TIME_HINT) && !text.match?(RiskScorer::DatePatterns::SPECIFIC_DATE_PATTERN)
          issues << {
            issue: "Vague timing",
            description: "The criteria references a time condition without a specific date, which could cause disagreement about when the deadline is.",
            affectedPhrase: text.match(VAGUE_TIME_HINT)&.to_s
          }
        end

        if text.match?(/widely|generally|most people|consensus/i)
          issues << {
            issue: "Subjective threshold",
            description: "The criteria uses language like 'widely' or 'generally' which has no clear numeric threshold and is open to interpretation.",
            affectedPhrase: text.match(/widely|generally|most people|consensus/i)&.to_s
          }
        end

        {
          hasAmbiguity: issues.any?,
          ambiguityLevel: (issues.length >= 2 ? "HIGH" : issues.length == 1 ? "MODERATE" : "NONE"),
          misinterpretations: issues.first(4),
          overallNote: issues.any? ? "Estimated analysis (AI unavailable): #{issues.length} potential ambiguity area(s) detected in the resolution criteria." : "Estimated analysis (AI unavailable): No obvious ambiguity detected.",
          market_type: nil,
          market_type_confidence: nil,
          market_type_reasoning: nil,
          factorExplanations: nil,
          from_fallback: true
        }
      end

      private

      def build_cache_key(title, criteria)
        "misinterpretation:v1:#{Digest::SHA256.hexdigest([title.to_s, criteria.to_s].join("\n"))}"
      end

      def no_criteria_result
        {
          hasAmbiguity: true,
          ambiguityLevel: "HIGH",
          misinterpretations: [],
          overallNote: "No resolution criteria provided — impossible to assess misinterpretation risk. Treat this market with extra caution.",
          market_type: nil,
          market_type_confidence: nil,
          market_type_reasoning: nil,
          factorExplanations: nil,
          from_fallback: true
        }
      end

      def system_prompt
        <<~SYSTEM
          You are a prediction market risk analyst. You analyse resolution criteria for ambiguity and classify market types.
          Always respond with a single JSON object only. No prose, no markdown, no text outside the JSON.
        SYSTEM
      end

      def user_prompt(criteria_text, market_title, category_label)
        <<~PROMPT
          Analyse this market and return a single JSON object only.

          Market title: "#{market_title}"
          Category label (unreliable — use only as a weak hint): "#{category_label}"
          Resolution criteria: "#{criteria_text}"

          Classify the market_type by reading the TITLE and RESOLUTION CRITERIA primarily.
          Treat the category label as a low-weight hint only — it is often mislabelled.

          market_type must be one of:
            CRYPTO_PRICE           — outcome is a verifiable price threshold or on-chain event
            SPORTS_OUTCOME         — outcome is a sports result with a clear official winner
            ELECTION_POLITICAL     — outcome is a political vote, appointment, or policy decision
            MACRO_ECONOMIC         — outcome is a macroeconomic stat, index level, or data release
            GEOPOLITICAL           — outcome involves conflict, diplomacy, or international events
            SUBJECTIVE_QUALITATIVE — outcome requires human judgment, has no objective measure,
                                     or the resolution criteria is vague/discretionary

          {
            "market_type": "<one of the six types above>",
            "market_type_confidence": <"HIGH" | "MEDIUM" | "LOW">,
            "market_type_reasoning": "<one sentence explaining why you chose this type, referencing specific words in the title or criteria>",
            "hasAmbiguity": <true | false>,
            "ambiguityLevel": <"NONE" | "LOW" | "MODERATE" | "HIGH">,
            "misinterpretations": [
              {
                "issue": "<short label>",
                "description": "<plain English description>",
                "affectedPhrase": "<exact short phrase or null>"
              }
            ],
            "overallNote": "<one sentence summary>",
            "factorExplanations": {
              "resolution_clarity": "<1-2 sentences about this specific market's criteria clarity>",
              "time_horizon": "<1-2 sentences about this market's deadline specificity>",
              "historical_accuracy": "<1-2 sentences about resolution reliability for this type of criteria>",
              "manipulation_risk": "<1-2 sentences about manipulation exposure given this criteria>",
              "information_asymmetry": "<1-2 sentences about information access asymmetry in this market>"
            },
            "factorScores": {
              "resolution_clarity": <integer 0-100>,
              "time_horizon": <integer 0-100>,
              "historical_accuracy": <integer 0-100>,
              "manipulation_risk": <integer 0-100>,
              "information_asymmetry": <integer 0-100>
            }
          }

          Scoring rules you must follow:
          - Base your market_type on the title and criteria text, not the category label.
          - If resolution criteria references a specific price feed, official API, or
            on-chain source: this strongly indicates objective resolution text.
          - If criteria uses words like "generally", "consensus", "widely",
            "community decides", or names no specific source: this increases ambiguity.
          - factorExplanations: write 1–2 sentences specific to THIS market's actual criteria,
            not generic statements. Reference specific phrases from the criteria when relevant.
          - factorScores: score each factor 0–100 where 0 = no risk and 100 = extreme risk.
            The score MUST be consistent with your factorExplanation for the same factor.
            Low risk → 0–39, Medium risk → 40–69, High risk → 70–100.

          Per-factor scoring direction (CRITICAL — read carefully):
          - resolution_clarity: HIGH score (70–100) means the criteria is VAGUE, SUBJECTIVE,
            or POORLY DEFINED. LOW score (0–39) means the criteria is CLEAR and OBJECTIVE.
            If your explanation describes ambiguity, undefined methodology, or subjectivity,
            the score MUST be 70+.
          - time_horizon: HIGH score means the deadline is FAR AWAY or UNSPECIFIED.
            LOW score means a NEAR, PRECISE deadline.
          - historical_accuracy: HIGH score means there is NO reliable track record or
            the resolution source is UNPROVEN. LOW score means well-established, verifiable sources.
          - manipulation_risk: HIGH score means the outcome is EASILY MANIPULATED or
            depends on a controllable source. LOW score means manipulation is very difficult.
          - information_asymmetry: HIGH score means INSIDERS have a major advantage.
            LOW score means all participants have roughly equal information access.
        PROMPT
      end

      def normalize_response(raw)
        type = normalize_market_type(raw["market_type"])
        type_confidence = normalize_market_type_confidence(raw["market_type_confidence"])
        normalized = {
          hasAmbiguity: !!raw["hasAmbiguity"],
          ambiguityLevel: raw["ambiguityLevel"].to_s.upcase.presence || "MODERATE",
          misinterpretations: Array(raw["misinterpretations"]).first(4).map do |item|
            {
              issue: item["issue"].to_s,
              description: item["description"].to_s,
              affectedPhrase: item["affectedPhrase"]
            }
          end,
          overallNote: raw["overallNote"].to_s,
          market_type: type,
          market_type_confidence: type_confidence,
          market_type_reasoning: raw["market_type_reasoning"].to_s.presence,
          factorExplanations: normalize_factor_explanations(raw["factorExplanations"]),
          factorScores: normalize_factor_scores(raw["factorScores"]),
          from_fallback: false
        }
        normalized[:ambiguityLevel] = "MODERATE" unless %w[NONE LOW MODERATE HIGH].include?(normalized[:ambiguityLevel])
        normalized
      end

      FACTOR_EXPLANATION_KEYS = %w[resolution_clarity time_horizon historical_accuracy manipulation_risk information_asymmetry].freeze

      def normalize_factor_explanations(raw)
        return nil unless raw.is_a?(Hash)
        result = FACTOR_EXPLANATION_KEYS.each_with_object({}) do |key, h|
          val = raw[key].to_s.strip
          h[key.to_sym] = val.present? ? val : nil
        end
        result.values.any?(&:present?) ? result : nil
      end

      def normalize_factor_scores(raw)
        return nil unless raw.is_a?(Hash)
        result = FACTOR_EXPLANATION_KEYS.each_with_object({}) do |key, h|
          val = raw[key].to_i
          h[key.to_sym] = val.between?(0, 100) ? val : nil
        end
        result.values.any?(&:present?) ? result : nil
      end

      def normalize_market_type(value)
        normalized = value.to_s.upcase.strip
        return nil unless %w[
          CRYPTO_PRICE
          SPORTS_OUTCOME
          ELECTION_POLITICAL
          MACRO_ECONOMIC
          GEOPOLITICAL
          SUBJECTIVE_QUALITATIVE
        ].include?(normalized)

        normalized
      end

      def normalize_market_type_confidence(value)
        normalized = value.to_s.upcase.strip
        return nil unless %w[HIGH MEDIUM LOW].include?(normalized)

        normalized
      end

    end
  end
end
