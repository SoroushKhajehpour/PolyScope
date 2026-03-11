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
    RiskScoreCalculationJob.perform_now(nil, market_ids: [m1.id, m2.id])
    assert RiskScore.exists?(market: m1)
    assert RiskScore.exists?(market: m2)
  end

  test "perform with no args runs without error" do
    RiskScoreCalculationJob.perform_now
  end

  test "perform with invalid market_id does not raise" do
    RiskScoreCalculationJob.perform_now(0)
  end

  test "markets_needing_scoring includes markets without risk_score" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )
    ids = RiskScoreCalculationJob.new.send(:markets_needing_scoring).pluck(:id)
    assert_includes ids, market.id
  end
end
