# frozen_string_literal: true

require "test_helper"

module RiskScorer
  class SourceDependencyRegexScorerTest < ActiveSupport::TestCase
    test "specific named source scores low" do
      text = "Resolution source will be information from the Federal Register."
      assert_equal 2, SourceDependencyRegexScorer.call(text)
    end

    test "consensus of credible reporting scores mid" do
      text = "Resolution based on consensus of credible reporting from major English-language outlets."
      score = SourceDependencyRegexScorer.call(text)
      assert score >= 9 && score <= 12, "Expected tier 3 (9-12), got #{score}"
    end

    test "no source scores high" do
      text = "This market resolves according to general knowledge."
      score = SourceDependencyRegexScorer.call(text)
      assert score >= 14, "Expected high score when no clear source, got #{score}"
    end

    test "blank or nil returns high score (no source)" do
      assert SourceDependencyRegexScorer.call("") >= 14
      assert SourceDependencyRegexScorer.call(nil) >= 14
    end

    test "BLS or AP with attribution gives low score" do
      text = "According to BLS employment data."
      assert SourceDependencyRegexScorer.call(text) <= 6
    end
  end
end
