# frozen_string_literal: true

# Factor 1 LLM component: 5 dimensions (0-5 each), summed to 0-25. Run 3× and average.
# Uses LlmCache (llm_score_caches table). API key from ENV only (LlmClient).
module RiskScorer
  class AmbiguityLlmScorer
    MAX_SCORE = 25
    RUNS = 3
    REGEX_WEIGHT = 0.2
    LLM_WEIGHT = 0.8

    class << self
      # @param resolution_criteria [String]
      # @param regex_pre_score [Integer] 0-25 from AmbiguityRegexScorer
      # @return [Float, nil] F1 combined score 0-25, or nil if LLM unavailable / all runs fail
      def call(resolution_criteria, regex_pre_score: nil)
        text = resolution_criteria.to_s.strip
        regex_pre_score ||= AmbiguityRegexScorer.call(text)

        llm_score = llm_score_for(text)
        return (REGEX_WEIGHT * regex_pre_score + LLM_WEIGHT * llm_score).round(2) if llm_score

        # Fallback: no API key or all LLM runs failed — use regex only as F1
        regex_pre_score.to_f
      end

      # @param resolution_criteria [String]
      # @return [Integer, nil] 0-25 from LLM (3× average), or nil
      def llm_score_for(resolution_criteria)
        text = resolution_criteria.to_s.strip
        return nil if text.blank?

        client = LlmClient.new
        return nil unless client.configured?

        prompt_version = RiskScoringConfig.prompt_version
        model_id = LlmClient::DEFAULT_MODEL
        cache_key = Digest::SHA256.hexdigest([model_id, prompt_version, text].join("\n"))

        cached = RiskScorer::LlmCache.get(cache_key)
        if cached.present? && cached["total"].is_a?(Numeric)
          return [[cached["total"].round, MAX_SCORE].min, 0].max
        end

        system_prompt = load_system_prompt
        return nil if system_prompt.blank?

        totals = []
        RUNS.times do
          result = client.chat(system: system_prompt, user: "Score this resolution criteria:\n\n#{text}", temperature: 0.0, model: model_id)
          total = result["total"]
          totals << total if total.is_a?(Numeric)
        end

        return nil if totals.empty?

        avg = totals.sum.to_f / totals.size
        score = [[avg.round, MAX_SCORE].min, 0].max
        RiskScorer::LlmCache.set(
          cache_key: cache_key,
          model_id: model_id,
          prompt_version: prompt_version,
          result_json: { "total" => score, "runs" => totals.size }
        )
        score
      end

      private

      def load_system_prompt
        path = Rails.root.join("app", "prompts", "ambiguity_scoring_system.txt")
        return nil unless path.exist?

        File.read(path).strip
      end
    end
  end
end
