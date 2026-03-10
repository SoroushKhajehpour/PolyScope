# frozen_string_literal: true

require "test_helper"

class EmbeddingClientTest < ActiveSupport::TestCase
  test "configured? is false when ENV OPENAI_API_KEY is blank" do
    with_env("OPENAI_API_KEY" => nil) do
      client = EmbeddingClient.new
      assert_not client.configured?
    end
  end

  test "configured? is true when ENV is set" do
    with_env("OPENAI_API_KEY" => "sk-test-dummy") do
      client = EmbeddingClient.new
      assert client.configured?
    end
  end

  test "embed returns nil when not configured" do
    with_env("OPENAI_API_KEY" => nil) do
      client = EmbeddingClient.new
      assert_nil client.embed("hello")
    end
  end

  test "embed returns nil for empty text" do
    with_env("OPENAI_API_KEY" => "sk-test") do
      client = EmbeddingClient.new
      assert_nil client.embed("")
      assert_nil client.embed("   ")
    end
  end

  test "initialize uses ENV when api_key not passed" do
    with_env("OPENAI_API_KEY" => "env-key") do
      client = EmbeddingClient.new
      assert client.configured?
    end
  end

  test "initialize uses passed api_key over ENV" do
    with_env("OPENAI_API_KEY" => "env-key") do
      client = EmbeddingClient.new(api_key: "passed-key")
      assert client.configured?
    end
  end

  test "dimensions returns 3072" do
    assert_equal 3072, EmbeddingClient.new.dimensions
  end

  def with_env(hash)
    old = ENV.to_h
    hash.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    hash.each_key { |k| ENV[k] = old[k] }
  end
end
