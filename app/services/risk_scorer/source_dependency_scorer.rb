# frozen_string_literal: true

# Factor 2 full: regex base + LLM when ambiguous, modifiers (revision-prone, editable, no fallback),
# known-manipulated check. Returns { score: 0-20, apply_source_floor: bool, available: bool }.
module RiskScorer
  class SourceDependencyScorer
    MAX_SCORE = 20

    # Regex scores in this range are "ambiguous" — call LLM to refine
    AMBIGUOUS_REGEX_SCORES = [6, 10, 12, 14].freeze

    # Modifier patterns
    REVISION_PRONE = /\bBLS\b.*?(?:initial|preliminary|first\s+release|without\s+specifying\s+(?:which|the)\s+release)/im
    REVISION_PRONE_SOURCE = /\bBLS\b/i
    EDITABLE_SOURCE = /\b(Wikipedia|OpenStreetMap|wikimedia|wikidata|user\s+editable)\b/i
    NO_FALLBACK = /\b(primary\s+source|single\s+source|only\s+(?:from|source)|one\s+source)\b.*(?:without|no)\s+(?:fallback|backup)/im

    class << self
      # @param market [Market] Must respond to :resolution_criteria
      # @return [Hash] { score: Integer (0-20), apply_source_floor: Boolean, available: Boolean }
      def call(market)
        text = (market.respond_to?(:resolution_criteria) ? market.resolution_criteria : market.to_s).to_s.strip
        apply_floor = known_manipulated?(text)

        base = RiskScorer::SourceDependencyRegexScorer.call(text)

        # LLM refinement when regex result is in ambiguous middle tier
        llm_available = true
        refined = if AMBIGUOUS_REGEX_SCORES.include?(base)
          llm_val = llm_score_for(text)
          llm_available = false if llm_val.nil?
          llm_val || base
        else
          base
        end

        score = apply_modifiers(refined, text)
        score = [[score, MAX_SCORE].min, 0].max

        { score: score, apply_source_floor: apply_floor, available: llm_available }
      end

      private

      def known_manipulated?(text)
        return false if text.blank?

        RiskScoringConfig.known_manipulated_sources.any? do |source|
          text =~ /\b#{Regexp.escape(source)}\b/i
        end
      end

      def apply_modifiers(score, text)
        s = score
        s += 2 if revision_prone?(text)
        s += 2 if editable_source?(text)
        s += 1 if no_fallback?(text)
        s
      end

      def revision_prone?(text)
        text.match?(REVISION_PRONE) ||
          (text.match?(REVISION_PRONE_SOURCE) && !text.match?(/\b(final|revised|benchmark|second\s+release)\b/i))
      end

      def editable_source?(text)
        text.match?(EDITABLE_SOURCE)
      end

      def no_fallback?(text)
        text.match?(NO_FALLBACK)
      end

      def llm_score_for(text)
        return nil if text.blank?

        client = LlmClient.new
        return nil unless client.configured?

        prompt_version = RiskScoringConfig.prompt_version
        model_id = LlmClient.default_model_id
        prefix = "source_classification"
        cache_key = Digest::SHA256.hexdigest([prefix, model_id, prompt_version, text].join("\n"))

        cached = RiskScorer::LlmCache.get(cache_key)
        if cached.present? && cached["score"].is_a?(Numeric)
          return [[cached["score"].round, MAX_SCORE].min, 0].max
        end

        system_prompt = load_system_prompt
        return nil if system_prompt.blank?

        result = client.chat(system: system_prompt, user: "Classify this resolution criteria:\n\n#{text}", temperature: 0.0, model: nil)
        score = parse_score(result)
        return nil if score.nil?

        score = [[score, MAX_SCORE].min, 0].max
        RiskScorer::LlmCache.set(
          cache_key: cache_key,
          model_id: model_id,
          prompt_version: prompt_version,
          result_json: { "score" => score }
        )
        score
      end

      def parse_score(result)
        return result["score"] if result["score"].is_a?(Numeric)
        nil
      end

      def load_system_prompt
        path = Rails.root.join("app", "prompts", "source_classification_system.txt")
        return nil unless path.exist?

        File.read(path).strip
      end
    end
  end
end
