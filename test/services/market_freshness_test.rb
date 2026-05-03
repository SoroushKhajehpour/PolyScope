# frozen_string_literal: true

require "test_helper"

class MarketFreshnessTest < ActiveSupport::TestCase
  test "summary is fresh when score is recent and no blocking signals" do
    market = Market.create!(
      event_id: "e-fresh-mf",
      event_question: "Q?",
      condition_id: "0xm1",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )

    s = MarketFreshness.summary(market)
    assert_equal MarketFreshness::FRESH, s[:freshness]
    assert_equal false, s[:blocking_display_stale]
  end

  test "blocking stale when clarification created after score" do
    market = Market.create!(
      event_id: "e-block-mf",
      event_question: "Q?",
      condition_id: "0xm2",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    score = market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 2.hours.ago
    )
    market.clarifications.create!(
      previous_text: "a",
      new_text: "b",
      detected_at: Time.current,
      created_at: score.computed_at + 10.minutes
    )

    market.reload
    assert MarketFreshness.blocking_display_stale?(market)
    s = MarketFreshness.summary(market)
    assert_equal MarketFreshness::BLOCKING_STALE, s[:freshness]
    assert_includes s[:stale_reason].to_s.downcase, "resolution"
  end
end
