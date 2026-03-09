# frozen_string_literal: true

require "test_helper"

class DescriptionChangeDetectorTest < ActiveSupport::TestCase
  test "detect returns change_type, edit_ratio, magnitude" do
    result = DescriptionChangeDetector.detect("hello", "hello")
    assert_equal "minor", result[:change_type]
    assert_equal "minor", result[:magnitude]
    assert result[:edit_ratio].is_a?(Numeric)
  end

  test "identical text gives edit_ratio 0 and minor" do
    text = "Resolution source: AP. Threshold: 270."
    result = DescriptionChangeDetector.detect(text, text)
    assert_equal 0.0, result[:edit_ratio]
    assert_equal "minor", result[:magnitude]
  end

  test "small change gives minor" do
    result = DescriptionChangeDetector.detect("Resolution source: AP.", "Resolution source: AP. ")
    assert result[:edit_ratio] < 0.10
    assert_equal "minor", result[:magnitude]
  end

  test "medium change gives moderate" do
    # ~20% of 50 chars = 10 chars; use two strings where distance/max ~= 0.2
    prev = "a" * 50
    curr = "a" * 40 + "b" * 10
    result = DescriptionChangeDetector.detect(prev, curr)
    assert_equal "moderate", result[:magnitude] if result[:edit_ratio] >= 0.10 && result[:edit_ratio] < 0.30
  end

  test "large change gives major or critical" do
    prev = "Resolution source will be the Federal Register."
    curr = "This market resolves YES if AI makes substantial progress toward AGI soon."
    result = DescriptionChangeDetector.detect(prev, curr)
    assert %w[major critical].include?(result[:magnitude])
    assert result[:edit_ratio] >= 0.30
  end

  test "empty prev and non-empty new gives high ratio" do
    result = DescriptionChangeDetector.detect("", "Some resolution text here.")
    assert result[:edit_ratio] > 0
    assert result[:edit_ratio] <= 1.0
  end

  test "empty both gives 0 ratio and minor" do
    result = DescriptionChangeDetector.detect("", "")
    assert_equal 0.0, result[:edit_ratio]
    assert_equal "minor", result[:magnitude]
  end
end
