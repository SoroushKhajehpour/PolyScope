# frozen_string_literal: true

# Reads/writes LLM scoring results in llm_score_caches. Cache key = hash(model + prompt_version + input_text).
# Never stores or logs API keys.
module RiskScorer
  class LlmCache
    TTL_HOURS = 24

    class << self
      # @param cache_key [String] Unique key (e.g. Digest::SHA256.hexdigest(model + prompt_version + text))
      # @return [Hash, nil] result_json if found and not expired, else nil
      def get(cache_key)
        return nil if cache_key.blank?

        record = LlmScoreCache.find_by(cache_key: cache_key)
        return nil unless record
        return nil if record.expires_at.nil? || record.expires_at < Time.current

        record.result_json.is_a?(Hash) ? record.result_json : {}
      end

      # @param cache_key [String]
      # @param model_id [String]
      # @param prompt_version [String]
      # @param result_json [Hash]
      def set(cache_key:, model_id:, prompt_version:, result_json:)
        return if cache_key.blank?

        now = Time.current
        expires = TTL_HOURS.hours.from_now
        LlmScoreCache.upsert_all(
          [{
            cache_key: cache_key,
            model_id: model_id,
            prompt_version: prompt_version,
            result_json: result_json,
            expires_at: expires,
            updated_at: now,
            created_at: now
          }],
          unique_by: :cache_key,
          update_only: %w[result_json expires_at updated_at]
        )
      end
    end
  end
end
