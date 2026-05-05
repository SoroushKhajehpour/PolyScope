# frozen_string_literal: true

require "test_helper"

class RiskScoreCalculationJobTest < ActiveSupport::TestCase
  test "perform with market_id creates or updates risk_score" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )
    RiskScoreCalculationJob.perform_now(market.id)
    record = RiskScore.find_by(market: market)
    assert record
    assert record.score.between?(0, 100)
    assert record.computed_at.present?
  end

  test "perform with market_ids processes each market" do
    m1 = Market.create!(event_id: "e1", event_question: "Q1", condition_id: "0x1", category: "Politics", status: "active", resolution_criteria: "Source: official.")
    m2 = Market.create!(event_id: "e2", event_question: "Q2", condition_id: "0x2", category: "Crypto", status: "active", resolution_criteria: "Date: 2025-06-01.")
    RiskScoreCalculationJob.perform_now(m1.id)
    RiskScoreCalculationJob.perform_now(m2.id)
    assert RiskScore.exists?(market: m1)
    assert RiskScore.exists?(market: m2)
  end

  test "perform with no args runs without error" do
    RiskScoreCalculationJob.perform_now
  end

  test "perform with invalid market_id does not raise" do
    RiskScoreCalculationJob.perform_now(0)
  end

  test "perform broadcasts score_complete on ActionCable after scoring" do
    market = Market.create!(
      event_id: "e-broadcast",
      event_question: "Q?",
      condition_id: "0x99",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )

    fake_result = { score: 37, level: "medium" }
    broadcast_calls = []

    fake_call = lambda do |m, persist: true, session_key: nil|
      m.risk_score || m.create_risk_score!(score: 37, level: "medium", factors: {}, computed_at: Time.current)
      fake_result
    end

    RiskScorer.stub(:call, fake_call) do
      ActionCable.server.stub(:broadcast, ->(channel, payload) { broadcast_calls << [channel, payload] }) do
        RiskScoreCalculationJob.perform_now(market.id)
      end
    end

    assert_equal 1, broadcast_calls.size
    channel, payload = broadcast_calls.first
    assert_equal "score_channel_#{market.id}", channel
    ev = payload.is_a?(Hash) ? (payload[:event] || payload["event"]) : nil
    assert_equal "score_complete", ev
  end

  test "perform persists fallback and broadcasts when resolution_criteria is blank" do
    market = Market.create!(
      event_id: "e-no-criteria",
      event_question: "Q?",
      condition_id: "0xnc",
      category: "Politics",
      status: "active",
      resolution_criteria: "Temporary."
    )
    market.update_column(:resolution_criteria, "   ")

    broadcast_calls = []
    ActionCable.server.stub(:broadcast, ->(*args) { broadcast_calls << args }) do
      RiskScoreCalculationJob.perform_now(market.id)
    end

    market.reload
    assert market.risk_score
    assert_equal true, market.risk_score.factor_metadata["scoring_fallback"]
    assert_equal 1, broadcast_calls.size
    channel, payload = broadcast_calls.first
    assert_equal "score_channel_#{market.id}", channel
    ev = payload.is_a?(Hash) ? (payload[:event] || payload["event"]) : nil
    assert_equal "score_complete", ev
  end

  test "perform runs RiskScorer when embedding step raises" do
    market = Market.create!(
      event_id: "e-embed-fail",
      event_question: "Q?",
      condition_id: "0xef",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )

    fake_call = lambda do |m, persist: true, session_key: nil|
      m.risk_score || m.create_risk_score!(score: 22, level: "low", factors: {}, computed_at: Time.current)
      { score: 22, level: "low" }
    end

    MarketEmbeddingJob.stub(:perform_now, ->(*_args, **_kwargs) { raise StandardError, "embedding unavailable" }) do
      RiskScorer.stub(:call, fake_call) do
        RiskScoreCalculationJob.perform_now(market.id)
      end
    end

    assert_equal 22, market.reload.risk_score.score
  end

  test "perform broadcasts score_complete after rescuing when scoring raises" do
    market = Market.create!(
      event_id: "e-broadcast-fail",
      event_question: "Q?",
      condition_id: "0xbf1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )

    broadcast_calls = []

    MarketEmbeddingJob.stub(:perform_now, ->(*_args, **_kwargs) { true }) do
      RiskScorer.stub(:call, ->(*_args, **_kwargs) { raise StandardError, "forced failure" }) do
        ActionCable.server.stub(:broadcast, ->(*args) { broadcast_calls << args }) do
          RiskScoreCalculationJob.perform_now(market.id)
        end
      end
    end

    assert_equal 1, broadcast_calls.size
    channel, payload = broadcast_calls.first
    assert_equal "score_channel_#{market.id}", channel
    ev = payload.is_a?(Hash) ? (payload[:event] || payload["event"]) : nil
    assert_equal "score_complete", ev
  end
end
