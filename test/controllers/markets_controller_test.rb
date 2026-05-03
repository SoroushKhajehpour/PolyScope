# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class MarketsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
  end

  test "live_search is read-only and returns mapped results" do
    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |_event_id|
      raise Faraday::Error, "not found"
    end
    fake_client.define_singleton_method(:search) do |_query|
      {
        "events" => [
          {
            "id" => "e-live-1",
            "title" => "Will X happen?",
            "image" => "https://example.com/i.png",
            "volume" => "12345",
            "markets" => [{ "endDate" => "2030-01-01T00:00:00Z", "conditionId" => "0xabc" }]
          }
        ]
      }
    end

    assert_no_difference("Market.count") do
      PolymarketClient.stub(:new, fake_client) do
        get live_search_markets_path(q: "x")
      end
    end

    assert_response :success
    assert_includes response.body, "Will X happen?"
  end

  test "show enqueues scoring and renders evaluating when score is missing" do
    market = Market.create!(
      event_id: "e-show-missing",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Resolved by official source."
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |event_id|
      {
        "id" => event_id,
        "title" => "Q?",
        "description" => "Resolved by official source.",
        "endDate" => 10.days.from_now.iso8601,
        "liquidity" => "1000",
        "volume" => "1000",
        "active" => true
      }
    end
    fake_client.define_singleton_method(:search) { |_query| { "events" => [] } }

    assert_enqueued_with(job: RiskScoreCalculationJob) do
      PolymarketClient.stub(:new, fake_client) do
        get market_path(market.event_id)
      end
    end

    assert_response :success
    assert_match(/MarketEvaluating/, response.body)
  end

  test "show renders result directly when score is fresh" do
    market = Market.create!(
      event_id: "e-show-fresh",
      event_question: "Fresh market?",
      condition_id: "0x2",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Resolved by official source."
    )
    market.create_risk_score!(
      score: 42,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |event_id|
      {
        "id" => event_id,
        "title" => "Fresh market?",
        "description" => "Resolved by official source.",
        "endDate" => 10.days.from_now.iso8601,
        "liquidity" => "1000",
        "volume" => "1000",
        "active" => true
      }
    end
    fake_client.define_singleton_method(:search) { |_query| { "events" => [] } }

    PolymarketClient.stub(:new, fake_client) do
      get market_path(market.event_id)
    end

    assert_response :success
    assert_includes response.body, "Risk Level"
    assert_includes response.body, "Score: 42"
  end

  test "show renders result when score exists but is only soft-stale (end date soon)" do
    market = Market.create!(
      event_id: "e-show-soft-stale",
      event_question: "Soon ending?",
      condition_id: "0x4",
      category: "Politics",
      status: "active",
      end_date: 12.hours.from_now,
      resolution_criteria: "Resolved by official source."
    )
    market.create_risk_score!(
      score: 55,
      level: "medium",
      factors: {},
      computed_at: 30.minutes.ago
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |event_id|
      {
        "id" => event_id,
        "title" => "Soon ending?",
        "description" => "Resolved by official source.",
        "endDate" => 12.hours.from_now.iso8601,
        "liquidity" => "1000",
        "volume" => "1000",
        "active" => true
      }
    end
    fake_client.define_singleton_method(:search) { |_query| { "events" => [] } }

    PolymarketClient.stub(:new, fake_client) do
      get market_path(market.event_id)
    end

    assert_response :success
    assert_includes response.body, "Risk Level"
    assert_includes response.body, "Score: 55"
    refute_match(/MarketEvaluating/, response.body)
  end

  test "show treats score as stale when clarification is newer than computed_at" do
    market = Market.create!(
      event_id: "e-show-stale",
      event_question: "Stale market?",
      condition_id: "0x3",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Resolved by official source."
    )
    score = market.create_risk_score!(
      score: 40,
      level: "medium",
      factors: {},
      computed_at: 1.hour.ago
    )
    market.clarifications.create!(
      previous_text: "A",
      new_text: "B",
      detected_at: Time.current,
      created_at: score.computed_at + 5.minutes
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |event_id|
      {
        "id" => event_id,
        "title" => "Stale market?",
        "description" => "Resolved by official source.",
        "endDate" => 10.days.from_now.iso8601,
        "liquidity" => "1000",
        "volume" => "1000",
        "active" => true
      }
    end
    fake_client.define_singleton_method(:search) { |_query| { "events" => [] } }

    assert_enqueued_with(job: RiskScoreCalculationJob) do
      PolymarketClient.stub(:new, fake_client) do
        get market_path(market.event_id)
      end
    end

    assert_response :success
    assert_match(/MarketEvaluating/, response.body)
  end

  test "digest returns freshness payload for known events" do
    market = Market.create!(
      event_id: "e-digest-1",
      event_question: "Digest Q?",
      condition_id: "0xd1",
      category: "Politics",
      status: "active",
      end_date: 10.days.from_now,
      resolution_criteria: "Official source."
    )
    market.create_risk_score!(
      score: 50,
      level: "medium",
      factors: {},
      computed_at: 2.hours.ago
    )

    post "/markets/digest", params: { event_ids: [market.event_id, "missing-id"] }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    markets = body["markets"]
    assert markets[market.event_id]["freshness"].present?
    assert_equal false, markets[market.event_id]["missing"]
    assert_equal true, markets["missing-id"]["missing"]
  end
end
