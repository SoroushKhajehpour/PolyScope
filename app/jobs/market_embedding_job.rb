# frozen_string_literal: true

# Generates and stores embeddings for a market's resolution_criteria (Factor 6).
# Skips if an embedding already exists with the same text hash.
# API key from ENV only; never exposed to frontend.
class MarketEmbeddingJob < ApplicationJob
  queue_as :default

  # @param market_id [Integer, nil] Specific market, or nil to process all
  # @param embedding_client [Object, nil] Optional client responding to #embed(text). Defaults to EmbeddingClient.new (for tests, pass a stub).
  def perform(market_id = nil, embedding_client: nil)
    client = embedding_client || EmbeddingClient.new
    if market_id
      market = Market.find_by(id: market_id)
      embed_market(market, client) if market
    else
      Market.find_each { |m| embed_market(m, client) }
    end
  end

  private

  def embed_market(market, client)
    text = market.resolution_criteria.to_s
    return if text.strip.empty?

    text_hash = Digest::SHA256.hexdigest(text)
    existing = market.market_embedding

    if existing && existing.embedded_text_hash == text_hash
      return
    end

    vector = client.embed(text)
    return unless vector.is_a?(Array) && vector.any?

    embedding_vector = Pgvector::Vector.new(vector)

    if existing
      existing.update!(
        embedded_text_hash: text_hash,
        embedding_model: EmbeddingClient::DEFAULT_MODEL,
        embedding_vector: embedding_vector
      )
    else
      market.create_market_embedding!(
        embedded_text_hash: text_hash,
        embedding_model: EmbeddingClient::DEFAULT_MODEL,
        embedding_vector: embedding_vector
      )
    end
  end
end
