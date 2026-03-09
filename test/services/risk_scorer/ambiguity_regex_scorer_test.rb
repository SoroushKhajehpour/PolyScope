# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class AmbiguityRegexScorerTest < ActiveSupport::TestCase
    test "low-risk text scores low" do
      # Research example: AP, Fox, NBC call election before January 20, 2025 — clear source and date
      text = "Resolution source will be AP, Fox News, and NBC. Market resolves YES if all call the election for Trump before January 20, 2025."
      score = AmbiguityRegexScorer.call(text)
      assert score < 15, "Expected low score for clear criteria, got #{score}"
    end

    test "high-risk text with subjective terms scores high" do
      text = "This market resolves YES if AI makes substantial progress toward AGI soon."
      score = AmbiguityRegexScorer.call(text)
      assert score >= 10, "Expected high score for subjective/vague text, got #{score}"
    end

    test "blank or empty returns max score (no info = high ambiguity)" do
      assert_equal 25, AmbiguityRegexScorer.call("")
      assert_equal 25, AmbiguityRegexScorer.call(nil)
    end

    test "score is capped at 25" do
      text = "Something significant and substantial. Perhaps possibly unclear. Many various. Soon. Generally typically. As appropriate. Deemed resolved. Credible reporting. Etc. Perhaps uncertain."
      score = AmbiguityRegexScorer.call(text)
      assert score <= 25, "Score must be capped at 25, got #{score}"
    end

    test "absence of date adds penalty" do
      no_date = "Resolution based on credible reporting."  # no date
      with_date = "Resolution based on credible reporting. By 2025-12-31."
      assert AmbiguityRegexScorer.call(no_date) >= AmbiguityRegexScorer.call(with_date)
    end
  end
end
