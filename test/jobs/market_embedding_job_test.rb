# frozen_string_literal: true

require "test_helper"

class MarketEmbeddingJobTest < ActiveSupport::TestCase
  test "perform with no market_id does not raise" do
    MarketEmbeddingJob.perform_now
  end

  test "perform with market_id skips when no resolution_criteria" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: ""
    )
    MarketEmbeddingJob.perform_now(market.id)
    assert_nil market.reload.market_embedding
  end

  test "perform creates embedding when client returns vector" do
    market = Market.create!(
      event_id: "e2",
      event_question: "Q2?",
      condition_id: "0x2",
      category: "Crypto",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )
    vector = [0.5] * 3072
    stub_client = Object.new
    stub_client.define_singleton_method(:embed) { |text, session_key: nil| text == "Resolved by official source." ? vector : nil }

    MarketEmbeddingJob.perform_now(market.id, embedding_client: stub_client)

    emb = market.reload.market_embedding
    assert emb
    assert_equal Digest::SHA256.hexdigest("Resolved by official source."), emb.embedded_text_hash
    assert_equal "text-embedding-3-large", emb.embedding_model
    assert emb.embedding_vector.present?
  end

  test "perform skips when embedding exists with same hash" do
    market = Market.create!(
      event_id: "e3",
      event_question: "Q3?",
      condition_id: "0x3",
      category: "Sci",
      status: "active",
      resolution_criteria: "Same text."
    )
    market.create_market_embedding!(
      embedded_text_hash: Digest::SHA256.hexdigest("Same text."),
      embedding_model: "text-embedding-3-large",
      embedding_vector: Pgvector::Vector.new([0.0] * 3072)
    )
    embed_called = []
    stub_client = Object.new
    stub_client.define_singleton_method(:embed) { |text, session_key: nil| embed_called << text; nil }

    MarketEmbeddingJob.perform_now(market.id, embedding_client: stub_client)

    assert_empty embed_called
  end
end
