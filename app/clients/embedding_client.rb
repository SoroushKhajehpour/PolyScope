# frozen_string_literal: true
require "digest"

# Wrapper for OpenAI embeddings API. API key from ENV only (never hardcoded).
# Optional: set OPENAI_API_KEY for embedding-based similar-market matching. Scoring works without it (Claude-only).
# Anthropic does not expose embeddings; this client uses OpenAI when configured.
class EmbeddingClient
  DEFAULT_BASE_URL = "https://api.openai.com"
  DEFAULT_MODEL = "text-embedding-3-large"
  DEFAULT_DIMENSIONS = 3072
  TIMEOUT_SECONDS = 8
  EMBEDDINGS_CACHE_TTL = 24.hours

  def initialize(api_key: nil, base_url: nil, model: nil)
    @api_key = api_key.presence || ENV["OPENAI_API_KEY"]
    @base_url = (base_url || ENV["OPENAI_EMBEDDING_BASE_URL"] || DEFAULT_BASE_URL).to_s.chomp("/")
    @model = (model || ENV["OPENAI_EMBEDDING_MODEL"] || DEFAULT_MODEL).to_s
  end

  def configured?
    @api_key.present?
  end

  # @param text [String] Text to embed
  # @return [Array<Float>, nil] Embedding vector (e.g. 3072 dims), or nil if not configured or error
  def embed(text, session_key: nil)
    return nil unless configured?
    return nil if text.to_s.strip.empty?

    normalized = text.to_s.strip
    cache_key = "openai:embeddings:v1:#{Digest::SHA256.hexdigest([@model, normalized].join("\n"))}"
    cached = Rails.cache.read(cache_key)
    return cached if cached.is_a?(Array) && cached.any?
    return nil if cached == "fallback_unavailable"

    dedupe_key = "openai:embeddings:dedupe:#{cache_key}"
    # Use `next`, never `return`, inside this block — `return` skips AiCallGovernor lock cleanup
    # and leaks @pending, deadlocking later embeds for the same text.
    RiskScorer::AiCallGovernor.with_dedup_lock(dedupe_key) do
      cached_again = Rails.cache.read(cache_key)
      next cached_again if cached_again.is_a?(Array) && cached_again.any?
      next nil if cached_again == "fallback_unavailable"

      budget = RiskScorer::AiCallGovernor.acquire_budget(provider: "openai", session_key: session_key)
      unless budget[:allowed]
        # Do not cache — budget may free on retry; caching looked like OpenAI was never used.
        Rails.logger.info("[EmbeddingClient] OpenAI call skipped (budget): #{budget[:reason]}")
        next nil
      end

      body = { model: @model, input: normalized }
      attempts = 0
      begin
        attempts += 1
        res = conn.post("/v1/embeddings", body)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed
        retry if attempts < 2
        raise
      end
      if defined?(ApiDiagnostics)
        ApiDiagnostics.record_call(service: "openai.embeddings")
        ApiDiagnostics.record_rate_limit(service: "openai.embeddings", headers: res.headers.to_h)
      end
      unless res.success?
        Rails.logger.warn("[EmbeddingClient] HTTP #{res.status} from OpenAI embeddings")
        next nil
      end

      data = res.body
      arr = data.dig("data", 0, "embedding")
      next nil unless arr.is_a?(Array)

      vector = arr.map { |x| x.to_f }
      Rails.cache.write(cache_key, vector, expires_in: EMBEDDINGS_CACHE_TTL)
      Rails.logger.info("[EmbeddingClient] OpenAI embedding OK (#{vector.size} dims, model=#{@model})")
      vector
    end
  rescue StandardError => e
    Rails.logger.warn("[EmbeddingClient] #{e.class}: #{e.message}") if defined?(Rails)
    Rails.cache.write(cache_key, "fallback_unavailable", expires_in: EMBEDDINGS_CACHE_TTL) if defined?(cache_key)
    nil
  end

  def dimensions
    DEFAULT_DIMENSIONS
  end

  private

  def conn
    @conn ||= Faraday.new(url: @base_url) do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
      f.request :json
      f.response :json
      f.request :authorization, "Bearer", @api_key
      f.adapter Faraday.default_adapter
    end
  end
end
