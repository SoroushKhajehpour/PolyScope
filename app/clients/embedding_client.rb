# frozen_string_literal: true

# Wrapper for OpenAI embeddings API. API key from ENV only (never hardcoded).
# Set OPENAI_API_KEY in .env (or production env). Used only server-side; never sent to frontend.
# Anthropic does not provide an embeddings API; this client uses OpenAI for vector embeddings.
class EmbeddingClient
  DEFAULT_BASE_URL = "https://api.openai.com"
  DEFAULT_MODEL = "text-embedding-3-large"
  DEFAULT_DIMENSIONS = 3072

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
  def embed(text)
    return nil unless configured?
    return nil if text.to_s.strip.empty?

    body = { model: @model, input: text.to_s.strip }
    res = conn.post("/v1/embeddings", body)
    raise "Embedding API error: #{res.status}" unless res.success?

    data = res.body
    arr = data.dig("data", 0, "embedding")
    return nil unless arr.is_a?(Array)

    arr.map { |x| x.to_f }
  rescue StandardError => e
    Rails.logger.warn("[EmbeddingClient] #{e.class}: #{e.message}") if defined?(Rails)
    nil
  end

  def dimensions
    DEFAULT_DIMENSIONS
  end

  private

  def conn
    @conn ||= Faraday.new(url: @base_url) do |f|
      f.request :json
      f.response :json
      f.request :authorization, "Bearer", @api_key
      f.adapter Faraday.default_adapter
    end
  end
end
