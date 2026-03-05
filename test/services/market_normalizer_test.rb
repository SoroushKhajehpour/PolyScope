# frozen_string_literal: true

require "test_helper"

class MarketNormalizerTest < ActiveSupport::TestCase
  def load_fixture(name)
    path = Rails.root.join("test", "fixtures", "gamma_api_responses", "#{name}.json")
    JSON.parse(File.read(path))
  end

  test "returns empty array for nil or non-array input" do
    assert_equal [], MarketNormalizer.call(nil)
    assert_equal [], MarketNormalizer.call({})
  end

  test "normalizes binary market from fixture" do
    raw = load_fixture("binary")
    result = MarketNormalizer.call(raw)

    assert_equal 1, result.size
    m = result.first
    assert_equal "531202", m.polymarket_id
    assert_equal "21662", m.group_id
    assert_equal "BitBoy convicted?", m.question
    assert_equal :binary, m.market_type
    assert_equal "active", m.status
    assert_equal "Court records", m.resolution_criteria

    assert_equal 2, m.outcomes.size
    assert_equal "Yes", m.outcomes[0][:label]
    assert_equal 0.137, m.outcomes[0][:probability]
    assert_equal "No", m.outcomes[1][:label]
    assert_equal 0.863, m.outcomes[1][:probability]

    assert m.volume.is_a?(Numeric)
    assert m.end_date.is_a?(Time)
  end

  test "normalizes multi-outcome market from fixture" do
    raw = load_fixture("multi_outcome")
    result = MarketNormalizer.call(raw)

    assert_equal 1, result.size
    m = result.first
    assert_equal "multi123", m.polymarket_id
    assert_equal :multi_outcome, m.market_type
    assert_equal 3, m.outcomes.size
    assert_equal "Trump", m.outcomes[0][:label]
    assert_equal 0.44, m.outcomes[0][:probability]
    assert_equal "Biden", m.outcomes[1][:label]
    assert_equal 0.42, m.outcomes[1][:probability]
    assert_equal "Other", m.outcomes[2][:label]
    assert_equal 0.14, m.outcomes[2][:probability]
  end

  test "normalizes scalar market from fixture" do
    raw = load_fixture("scalar")
    result = MarketNormalizer.call(raw)

    assert_equal 1, result.size
    m = result.first
    assert_equal "scalar456", m.polymarket_id
    assert_equal :scalar, m.market_type
    assert_equal 1, m.outcomes.size
    assert_equal "Current", m.outcomes[0][:label]
    assert_equal 72400.5, m.outcomes[0][:value]
    assert_equal 60000.0, m.outcomes[0][:range_min]
    assert_equal 90000.0, m.outcomes[0][:range_max]
  end

  test "skips entries with blank id" do
    raw = [{ "id" => "", "question" => "No id" }, { "id" => "123", "question" => "OK", "outcomes" => "[\"Yes\", \"No\"]", "outcomePrices" => "[0.5, 0.5]" }]
    result = MarketNormalizer.call(raw)
    assert_equal 1, result.size
    assert_equal "123", result.first.polymarket_id
  end

  test "returns one struct per array element when no grouping" do
    raw = load_fixture("binary") + load_fixture("multi_outcome")
    result = MarketNormalizer.call(raw)
    assert_equal 2, result.size
    assert_equal "531202", result[0].polymarket_id
    assert_equal "multi123", result[1].polymarket_id
  end
end
