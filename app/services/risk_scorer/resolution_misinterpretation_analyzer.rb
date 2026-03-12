# frozen_string_literal: true

require "digest"
require "json"

module RiskScorer
  class ResolutionMisinterpretationAnalyzer
    OPENAI_BASE_URL = "https://api.openai.com"
    OPENAI_MODEL = "gpt-4o-mini"
    MISINTERPRETATION_CACHE_TTL = 24.hours
    VAGUE_TIME_HINT = /\b(?:before|after|by|prior to)\b/i

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
        return cached.deep_symbolize_keys if cached.present?

        if criteria_text.blank?
          result = no_criteria_result
          Rails.cache.write(cache_key, result, expires_in: MISINTERPRETATION_CACHE_TTL)
          return result
        end

        dedupe_key = "misinterpretation:#{cache_key}"
        RiskScorer::AiCallGovernor.with_dedup_lock(dedupe_key) do
          cached_again = Rails.cache.read(cache_key)
          return cached_again.deep_symbolize_keys if cached_again.present?

          budget = RiskScorer::AiCallGovernor.acquire_budget(provider: "openai", session_key: session_key)
          unless budget[:allowed]
            fallback = fallback_misinterpretation_analysis(criteria_text).merge(
              from_fallback: true,
              fallback_reason: budget[:reason]
            )
            Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL)
            return fallback
          end

          key = ENV["OPENAI_API_KEY"].to_s
          unless key.present?
            fallback = fallback_misinterpretation_analysis(criteria_text).merge(from_fallback: true)
            Rails.cache.write(cache_key, fallback, expires_in: MISINTERPRETATION_CACHE_TTL)
            return fallback
          end

          route = select_model_for(market_title)
          response = chat_completion(criteria_text, market_title, category_label, key, model: route[:model], max_tokens: route[:max_tokens])
          parsed = normalize_response(response)
          Rails.cache.write(cache_key, parsed, expires_in: MISINTERPRETATION_CACHE_TTL)
          parsed
        end
      rescue StandardError
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
          from_fallback: true
        }
      end

      def prompt(criteria_text, market_title, category_label)
        <<~PROMPT
          You are a prediction market risk analyst.

          Analyse this market and return a single JSON object only.
          No prose. No markdown. No text outside the JSON.

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
            "overallNote": "<one sentence summary>"
          }

          Scoring rules you must follow:
          - Base your market_type on the title and criteria text, not the category label.
          - If resolution criteria references a specific price feed, official API, or
            on-chain source: this strongly indicates objective resolution text.
          - If criteria uses words like "generally", "consensus", "widely",
            "community decides", or names no specific source: this increases ambiguity.
        PROMPT
      end

      def chat_completion(criteria_text, market_title, category_label, api_key, model:, max_tokens:)
        conn = Faraday.new(url: OPENAI_BASE_URL) do |f|
          f.request :json
          f.response :json
          f.request :authorization, "Bearer", api_key
          f.options.timeout = 8
          f.options.open_timeout = 8
          f.adapter Faraday.default_adapter
        end

        attempts = 0
        begin
          attempts += 1
          response = conn.post("/v1/chat/completions", {
            model: model,
            temperature: 0.1,
            max_tokens: max_tokens,
            messages: [{ role: "user", content: prompt(criteria_text, market_title, category_label) }]
          })
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed
          retry if attempts < 2
          raise
        end

        ApiDiagnostics.record_call(service: "openai.misinterpretation") if defined?(ApiDiagnostics)
        ApiDiagnostics.record_rate_limit(service: "openai.misinterpretation", headers: response.headers.to_h) if defined?(ApiDiagnostics)

        raise "OpenAI chat error: #{response.status}" unless response.success?

        text = response.dig("choices", 0, "message", "content").to_s
        JSON.parse(text)
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
          from_fallback: false
        }
        normalized[:ambiguityLevel] = "MODERATE" unless %w[NONE LOW MODERATE HIGH].include?(normalized[:ambiguityLevel])
        normalized
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

      def select_model_for(market_title)
        if objective_market_title?(market_title)
          { provider: :openai, model: OPENAI_MODEL, max_tokens: 400 }
        else
          { provider: :openai, model: OPENAI_MODEL, max_tokens: 600 }
        end
      end

      def objective_market_title?(title)
        keywords = %w[price above below exceed reach $ btc eth bitcoin ethereum crypto win championship election vote percent rate gdp index]
        t = title.to_s.downcase
        keywords.any? { |k| t.include?(k) }
      end
    end
  end
end
