# frozen_string_literal: true

# Generates and stores embeddings for a market's resolution_criteria (Factor 6).
# Skips if an embedding already exists with the same text hash.
# API key from ENV only; never exposed to frontend.
class MarketEmbeddingJob < ApplicationJob
  queue_as :default

  # @param market_id [Integer, nil] Specific market only (explicit user selection trigger)
  # @param embedding_client [Object, nil] Optional client responding to #embed(text). Defaults to EmbeddingClient.new (for tests, pass a stub).
  def perform(market_id = nil, embedding_client: nil, session_key: nil)
    client = embedding_client || EmbeddingClient.new
    return if market_id.blank?

    market = Market.find_by(id: market_id)
    embed_market(market, client, session_key: session_key) if market
  end

  private

  def embed_market(market, client, session_key: nil)
    text = market.resolution_criteria.to_s
    return if text.strip.empty?

    text_hash = Digest::SHA256.hexdigest(text)
    existing = market.market_embedding

    if existing && existing.embedded_text_hash == text_hash && existing.embedding_vector.present?
      return
    end

    vector = client.embed(text, session_key: session_key)
    return unless vector.is_a?(Array) && vector.any?

    # String form (e.g. "[0.1,0.2,...]") — Rails 8 bind quoting does not handle Pgvector::Vector on INSERT.
    embedding_literal = Pgvector.encode(vector)

    if existing
      existing.update!(
        embedded_text_hash: text_hash,
        embedding_model: EmbeddingClient::DEFAULT_MODEL,
        embedding_vector: embedding_literal
      )
    else
      market.create_market_embedding!(
        embedded_text_hash: text_hash,
        embedding_model: EmbeddingClient::DEFAULT_MODEL,
        embedding_vector: embedding_literal
      )
    end
  end
end
