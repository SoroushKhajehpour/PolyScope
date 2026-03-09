# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class LlmCacheTest < ActiveSupport::TestCase
    test "get returns nil for missing key" do
      assert_nil LlmCache.get("nonexistent-key-#{SecureRandom.hex(8)}")
    end

    test "get returns nil for expired record" do
      key = "test-expired-#{SecureRandom.hex(8)}"
      LlmScoreCache.create!(
        cache_key: key,
        model_id: "claude-test",
        prompt_version: "1.0",
        result_json: { "total" => 5 },
        expires_at: 1.hour.ago
      )
      assert_nil LlmCache.get(key)
    end

    test "get returns result_json when found and not expired" do
      key = "test-valid-#{SecureRandom.hex(8)}"
      LlmScoreCache.create!(
        cache_key: key,
        model_id: "claude-test",
        prompt_version: "1.0",
        result_json: { "total" => 12 },
        expires_at: 1.hour.from_now
      )
      result = LlmCache.get(key)
      assert_equal 12, result["total"]
    end

    test "set persists and get retrieves" do
      key = "test-set-#{SecureRandom.hex(8)}"
      LlmCache.set(
        cache_key: key,
        model_id: "model-1",
        prompt_version: "1.0",
        result_json: { "total" => 7 }
      )
      assert_equal 7, LlmCache.get(key)["total"]
    end
  end
end
