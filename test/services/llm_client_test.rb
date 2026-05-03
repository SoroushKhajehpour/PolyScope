# frozen_string_literal: true

require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  test "configured? is false when ENV ANTHROPIC_API_KEY is blank" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      client = LlmClient.new
      assert_not client.configured?
    end
  end

  test "configured? is true when ENV is set" do
    with_env("ANTHROPIC_API_KEY" => "sk-test-dummy") do
      client = LlmClient.new
      assert client.configured?
    end
  end

  test "chat returns {} when not configured" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      client = LlmClient.new
      assert_equal({}, client.chat(system: "You are helpful.", user: "Hi"))
    end
  end

  test "initialize uses ENV when api_key not passed" do
    with_env("ANTHROPIC_API_KEY" => "env-key") do
      client = LlmClient.new
      assert client.configured?
    end
  end

  test "initialize uses passed api_key over ENV" do
    with_env("ANTHROPIC_API_KEY" => "env-key") do
      client = LlmClient.new(api_key: "passed-key")
      assert client.configured?
    end
  end

  test "default_model_id reads ANTHROPIC_MODEL when set" do
    with_env("ANTHROPIC_MODEL" => "claude-test-model") do
      assert_equal "claude-test-model", LlmClient.default_model_id
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
