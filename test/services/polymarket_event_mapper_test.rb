# frozen_string_literal: true

require "test_helper"

class PolymarketEventMapperTest < ActiveSupport::TestCase
  test "build_events_from_markets returns empty for nil or non-array" do
    assert_equal([], PolymarketEventMapper.build_events_from_markets(nil))
    assert_equal([], PolymarketEventMapper.build_events_from_markets({}))
  end

  test "build_events_from_markets groups by event_id and returns one attrs per event" do
    markets = [
      { "id" => "m1", "closed" => false, "events" => [{ "id" => "e1", "title" => "Event One", "image" => "https://a.com/1.jpg" }], "volumeNum" => 100, "volume" => "100", "endDate" => "2026-12-31T00:00:00Z", "tags" => [{ "label" => "Politics" }] },
      { "id" => "m2", "closed" => false, "events" => [{ "id" => "e1", "title" => "Event One", "image" => "https://a.com/1.jpg" }], "volumeNum" => 50, "volume" => "50", "endDate" => "2026-12-31T00:00:00Z", "tags" => [] }
    ]
    result = PolymarketEventMapper.build_events_from_markets(markets)

    assert_equal 1, result.size
    attrs = result.first
    assert_equal "e1", attrs[:event_id]
    assert_equal "e1", attrs[:polymarket_id]
    assert_equal "Event One", attrs[:event_question]
    assert_equal "https://a.com/1.jpg", attrs[:event_image]
    assert_equal 150.0, attrs[:volume]
    assert_equal "Politics", attrs[:category]
    assert_equal "active", attrs[:status]
  end

  test "build_events_from_markets skips markets without event_id" do
    markets = [
      { "id" => "m1", "closed" => false, "events" => [], "volume" => "10" }
    ]
    result = PolymarketEventMapper.build_events_from_markets(markets)
    assert_equal [], result
  end

  test "build_event_from_search_event returns one attrs hash from event" do
    event = {
      "id" => "237569",
      "title" => "Next Supreme Leader of Iran?",
      "image" => "https://example.com/iran.png",
      "volume" => 17_226_438.41,
      "closed" => false
    }
    attrs = PolymarketEventMapper.build_event_from_search_event(event)

    assert_equal "237569", attrs[:event_id]
    assert_equal "237569", attrs[:polymarket_id]
    assert_equal "Next Supreme Leader of Iran?", attrs[:event_question]
    assert_equal "https://example.com/iran.png", attrs[:event_image]
    assert_equal 17_226_438.41, attrs[:volume]
    assert_equal "active", attrs[:status]
  end

  test "build_event_from_search_event returns empty if event_id blank" do
    assert_equal({}, PolymarketEventMapper.build_event_from_search_event("id" => ""))
    assert_equal({}, PolymarketEventMapper.build_event_from_search_event({}))
  end
end
