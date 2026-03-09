# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class AmbiguityLlmScorerTest < ActiveSupport::TestCase
    test "call returns regex-only score when LLM not configured" do
      with_env("ANTHROPIC_API_KEY" => nil) do
        text = "Resolution: Federal Register. 2025-06-01. Above 100."
        regex_score = AmbiguityRegexScorer.call(text)
        result = AmbiguityLlmScorer.call(text)
        assert result.is_a?(Numeric)
        assert_equal regex_score.to_f, result, "When no API key, F1 should equal regex pre-score"
      end
    end

    test "call returns combined score when cache hit" do
      text = "Some resolution criteria here."
      cache_key = Digest::SHA256.hexdigest([LlmClient::DEFAULT_MODEL, RiskScoringConfig.prompt_version, text].join("\n"))
      LlmScoreCache.create!(
        cache_key: cache_key,
        model_id: LlmClient::DEFAULT_MODEL,
        prompt_version: RiskScoringConfig.prompt_version,
        result_json: { "total" => 10 },
        expires_at: 1.hour.from_now
      )
      with_env("ANTHROPIC_API_KEY" => "sk-test") do
        # Should not call API — cache hit
        result = AmbiguityLlmScorer.call(text)
        assert result.is_a?(Numeric)
        assert result.between?(0, 25)
      end
    end

    test "llm_score_for returns nil when client not configured" do
      with_env("ANTHROPIC_API_KEY" => nil) do
        assert_nil AmbiguityLlmScorer.llm_score_for("Any text")
      end
    end

    def with_env(hash)
      old = ENV.to_h
      hash.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      yield
    ensure
      hash.each_key { |k| ENV[k] = old[k] }
    end
  end
end
