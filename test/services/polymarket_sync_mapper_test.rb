# frozen_string_literal: true

require "test_helper"

class PolymarketSyncMapperTest < ActiveSupport::TestCase
  test "returns empty hash for blank input" do
    assert_equal({}, PolymarketSyncMapper.to_market_attributes(nil))
    assert_equal({}, PolymarketSyncMapper.to_market_attributes({}))
    assert_equal({}, PolymarketSyncMapper.to_market_attributes("id" => ""))
  end

  test "maps binary market with event to Market attrs" do
    hash = {
      "id" => "531202",
      "question" => "BitBoy convicted?",
      "resolutionSource" => "Court records",
      "endDate" => "2026-03-31T12:00:00Z",
      "volume" => "48696.45",
      "closed" => false,
      "events" => [
        { "id" => "21662", "title" => "BitBoy convicted?", "image" => "https://example.com/img.jpg" }
      ],
      "tags" => [{ "label" => "Crypto" }]
    }
    attrs = PolymarketSyncMapper.to_market_attributes(hash)

    assert_equal "531202", attrs[:polymarket_id]
    assert_equal "BitBoy convicted?", attrs[:question]
    assert_equal "21662", attrs[:event_id]
    assert_equal "BitBoy convicted?", attrs[:event_question]
    assert_equal "https://example.com/img.jpg", attrs[:event_image]
    assert_equal "Court records", attrs[:resolution_criteria]
    assert_equal "Crypto", attrs[:category]
    assert_equal "active", attrs[:status]
    assert attrs[:volume].is_a?(Float)
    assert attrs[:end_date].present?
  end

  test "uses event title for event_question when present" do
    hash = {
      "id" => "123",
      "question" => "Will X happen by June?",
      "events" => [{ "id" => "ev1", "title" => "Next Supreme Leader of Iran?", "image" => nil }]
    }
    attrs = PolymarketSyncMapper.to_market_attributes(hash)
    assert_equal "Next Supreme Leader of Iran?", attrs[:event_question]
    assert_equal "ev1", attrs[:event_id]
  end
end
