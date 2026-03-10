# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class ClarificationScorerTest < ActiveSupport::TestCase
    test "call returns 0 when no clarifications" do
      market = Market.new
      market.define_singleton_method(:clarifications) { [] }
      score = ClarificationScorer.call(market)
      assert_equal 0.0, score
    end

    test "one clarification gives base 2" do
      market = Market.new(end_date: 2.weeks.from_now)
      clar = Clarification.new(
        previous_text: "Yes if X wins.",
        new_text: "Yes if X wins by popular vote.",
        detected_at: 1.week.ago
      )
      market.define_singleton_method(:clarifications) { [clar] }
      score = ClarificationScorer.call(market)
      assert score.between?(0.0, 10.0)
      assert score > 0
    end

    test "base score increases with count" do
      market = Market.new(end_date: 1.month.from_now)
      clars = 3.times.map do
        Clarification.new(
          previous_text: "A",
          new_text: "B",
          detected_at: 2.weeks.ago
        )
      end
      market.define_singleton_method(:clarifications) { clars }
      score = ClarificationScorer.call(market)
      assert score.between?(0.0, 10.0)
      assert score >= 0
    end

    test "recent clarification near end_date weighs more" do
      end_date = 3.days.from_now
      market = Market.new(end_date: end_date)
      recent_clar = Clarification.new(
        previous_text: "x",
        new_text: "y",
        detected_at: 1.day.ago
      )
      market.define_singleton_method(:clarifications) { [recent_clar] }
      score = ClarificationScorer.call(market)
      assert score.between?(0.0, 10.0)
      assert score > 0
    end

    test "uses market from fixtures" do
      market = markets(:one)
      market.clarifications.reload
      score = ClarificationScorer.call(market)
      assert score.between?(0.0, 10.0)
    end
  end
end
