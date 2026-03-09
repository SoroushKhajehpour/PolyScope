# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class TimeSpecScorerTest < ActiveSupport::TestCase
    test "returns 0 for ISO datetime with timezone" do
      assert_equal 0, TimeSpecScorer.call("Settlement: 2025-03-15T18:00:00Z")
      assert_equal 0, TimeSpecScorer.call("Before 2026-01-20T00:00:00+00:00")
    end

    test "returns 1 for datetime with named TZ" do
      assert_equal 1, TimeSpecScorer.call("Deadline March 15, 2025 at 3pm EST")
    end

    test "returns 5 for specific date without time" do
      assert_equal 5, TimeSpecScorer.call("Resolution as of 2025-03-15")
      assert_equal 5, TimeSpecScorer.call("By January 20, 2025")
    end

    test "returns 9 for month or quarter" do
      assert_equal 9, TimeSpecScorer.call("By March 2025")
      assert_equal 9, TimeSpecScorer.call("Q2 2025")
    end

    test "returns 10 for year only" do
      assert_equal 10, TimeSpecScorer.call("Will it happen in 2025?")
    end

    test "returns 13 for vague temporal" do
      assert_equal 13, TimeSpecScorer.call("Resolves YES if AI makes substantial progress soon")
      assert_equal 13, TimeSpecScorer.call("In the near future")
    end

    test "returns 15 for no temporal specification" do
      assert_equal 15, TimeSpecScorer.call("Resolution source: court records.")
      assert_equal 15, TimeSpecScorer.call("")
      assert_equal 15, TimeSpecScorer.call(nil)
    end
  end
end
