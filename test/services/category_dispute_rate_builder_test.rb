# frozen_string_literal: true

require "test_helper"

class CategoryDisputeRateBuilderTest < ActiveSupport::TestCase
  test "build upserts category dispute rates with Bayesian smoothing" do
    Market.create!(event_id: "e1", event_question: "Q1", condition_id: "0xaaa", category: "Politics", status: "active")
    Market.create!(event_id: "e2", event_question: "Q2", condition_id: "0xbbb", category: "Politics", status: "active")
    Market.create!(event_id: "e3", event_question: "Q3", condition_id: "0xccc", category: "Crypto", status: "active")

    requests = [
      { condition_id: "0xaaa", disputed: false },
      { condition_id: "0xbbb", disputed: true },
      { condition_id: "0xccc", disputed: true }
    ]
    CategoryDisputeRateBuilder.new(requests: requests).build

    politics = CategoryDisputeRate.find_by(category_slug: "politics")
    assert politics
    assert_equal 2, politics.total_markets
    assert_equal 1, politics.disputed_count
    # Raw rate 50%; smoothed (2*50 + 10*66.67)/(2+10) ≈ 63.9 (global = 2/3)
    assert politics.dispute_rate_pct > 0
    assert politics.dispute_rate_pct <= 100

    crypto = CategoryDisputeRate.find_by(category_slug: "crypto")
    assert crypto
    assert_equal 1, crypto.total_markets
    assert_equal 1, crypto.disputed_count
  end

  test "build does nothing when no requests" do
    CategoryDisputeRateBuilder.new(requests: []).build
    assert_equal 0, CategoryDisputeRate.count
  end

  test "build does nothing when no markets match condition_ids" do
    Market.create!(event_id: "e1", event_question: "Q1", condition_id: nil, category: "Politics", status: "active")
    requests = [{ condition_id: "0xnonexistent", disputed: true }]
    CategoryDisputeRateBuilder.new(requests: requests).build
    assert_equal 0, CategoryDisputeRate.count
  end
end
