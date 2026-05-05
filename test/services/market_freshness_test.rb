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

  test "past end_date is not treated as closing within 24 hours" do
    market = Market.create!(
      event_id: "e-past-end",
      event_question: "Ended market?",
      condition_id: "0xpe",
      category: "Politics",
      status: "resolved",
      end_date: 2.months.ago,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )
    market.reload

    assert MarketFreshness.score_fresh?(market)
    s = MarketFreshness.summary(market)
    assert_equal MarketFreshness::FRESH, s[:freshness]
    refute_includes s[:stale_reason].to_s, "24 hours"
  end

  test "future end_date within 24 hours adds stale reason when score cache is not valid" do
    market = Market.create!(
      event_id: "e-soon-end",
      event_question: "Soon?",
      condition_id: "0xse",
      category: "Politics",
      status: "active",
      end_date: 6.hours.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 5.hours.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )
    market.reload

    assert_not MarketFreshness.score_fresh?(market)
    s = MarketFreshness.summary(market)
    assert_equal MarketFreshness::SOFT_STALE, s[:freshness]
    assert_includes s[:stale_reason].to_s, "24 hours"
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

  test "timeline sort does not raise on blank timestamps" do
    t = MarketFreshness.send(:timeline_entry_timestamp, { at: nil })
    assert_kind_of Time, t

    t2 = MarketFreshness.send(:timeline_entry_timestamp, { "at" => "not-a-date" })
    assert_kind_of Time, t2
  end

  test "from_fallback alone is not blocking when LLM is configured (heuristic path is valid)" do
    market = Market.create!(
      event_id: "e-heuristic-mf",
      event_question: "Q?",
      condition_id: "0xm3",
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
      factor_metadata: { "resolution_analysis" => { "from_fallback" => true, "overallNote" => "Estimated" } }
    )
    market.reload

    llm_on = Object.new
    llm_on.define_singleton_method(:configured?) { true }
    LlmClient.stub(:new, llm_on) do
      assert_not MarketFreshness.blocking_display_stale?(market)
      s = MarketFreshness.summary(market)
      assert_equal MarketFreshness::FRESH, s[:freshness]
    end
  end

  test "provisional scoring_fallback is soft stale when LLM configured (not blocking display)" do
    market = Market.create!(
      event_id: "e-prov-mf",
      event_question: "Q?",
      condition_id: "0xm4",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 50,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago,
      factor_metadata: {
        "scoring_fallback" => true,
        "resolution_analysis" => { "from_fallback" => true, "fallback_reason" => "scoring_error" }
      }
    )
    market.reload

    llm_on = Object.new
    llm_on.define_singleton_method(:configured?) { true }
    LlmClient.stub(:new, llm_on) do
      assert_not MarketFreshness.blocking_display_stale?(market)
      assert_not MarketFreshness.scoring_cache_valid?(market)
      s = MarketFreshness.summary(market)
      assert_equal MarketFreshness::SOFT_STALE, s[:freshness]
      assert_nil s[:stale_reason]
    end
  end

  test "override_gate error_fallback is soft stale when LLM configured (not blocking display)" do
    market = Market.create!(
      event_id: "e-gate-mf",
      event_question: "Q?",
      condition_id: "0xm5",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 50,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago,
      override_gate_applied: "error_fallback",
      factor_metadata: { "resolution_analysis" => { "from_fallback" => true } }
    )
    market.reload

    llm_on = Object.new
    llm_on.define_singleton_method(:configured?) { true }
    LlmClient.stub(:new, llm_on) do
      assert_not MarketFreshness.blocking_display_stale?(market)
      assert_not MarketFreshness.scoring_cache_valid?(market)
      s = MarketFreshness.summary(market)
      assert_equal MarketFreshness::SOFT_STALE, s[:freshness]
    end
  end

  test "scoring_cache_valid when successful score within four hours and no clarifications" do
    market = Market.create!(
      event_id: "e-cache-ok",
      event_question: "Q?",
      condition_id: "0xc1",
      category: "Politics",
      status: "active",
      end_date: 12.hours.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 30.minutes.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )
    market.reload

    assert MarketFreshness.scoring_cache_valid?(market)
    assert_not MarketFreshness.score_fresh?(market)

    s = MarketFreshness.summary(market)
    assert_equal MarketFreshness::FRESH, s[:freshness]
    assert_nil s[:stale_reason]
  end

  test "scoring_cache_invalid when score older than four hours" do
    market = Market.create!(
      event_id: "e-cache-old",
      event_question: "Q?",
      condition_id: "0xc2",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 5.hours.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )
    market.reload

    assert_not MarketFreshness.scoring_cache_valid?(market)
  end

  test "scoring_cache_invalid when clarification after computed_at" do
    market = Market.create!(
      event_id: "e-cache-clar",
      event_question: "Q?",
      condition_id: "0xc3",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    score = market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago,
      factor_metadata: { "resolution_analysis" => { "from_fallback" => false } }
    )
    market.clarifications.create!(
      previous_text: "a",
      new_text: "b",
      detected_at: Time.current,
      created_at: score.computed_at + 1.minute
    )
    market.reload

    assert_not MarketFreshness.scoring_cache_valid?(market)
  end

  test "criteria_timeline snapshot includes full_text while summary stays truncated" do
    long_text = "#{'word ' * 80}ENDMARKER"
    market = Market.create!(
      event_id: "e-timeline-ft",
      event_question: "Q?",
      condition_id: "0xtl",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.market_description_snapshots.create!(
      description_text: long_text,
      description_hash: "abc123",
      snapshot_at: Time.current,
      detected_change_type: "critical"
    )
    market.reload

    timeline = MarketFreshness.criteria_timeline(market)
    snap = timeline.find { |e| e[:type] == "snapshot" }
    assert snap, "expected a snapshot entry"
    assert_equal long_text, snap[:full_text]
    assert_operator snap[:summary].length, :<, long_text.length
    assert_includes snap[:full_text], "ENDMARKER"
    refute_includes snap[:summary], "ENDMARKER"
  end

  test "criteria_timeline clarification includes full_text while summary stays truncated" do
    long_text = "#{'criteria ' * 80}ENDMARKER"
    market = Market.create!(
      event_id: "e-timeline-clar-ft",
      event_question: "Q?",
      condition_id: "0xtlc",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.clarifications.create!(
      previous_text: "old criteria",
      new_text: long_text,
      detected_at: Time.current
    )
    market.reload

    timeline = MarketFreshness.criteria_timeline(market)
    clarification = timeline.find { |e| e[:type] == "clarification" }
    assert clarification, "expected a clarification entry"
    assert_equal long_text, clarification[:full_text]
    assert_operator clarification[:summary].length, :<, long_text.length
    assert_includes clarification[:full_text], "ENDMARKER"
    refute_includes clarification[:summary], "ENDMARKER"
  end
end
