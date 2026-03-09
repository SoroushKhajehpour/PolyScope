# frozen_string_literal: true

require "test_helper"

class UmaClientTest < ActiveSupport::TestCase
  test "fetch_price_requests returns array of condition_id and disputed" do
    stub_body = {
      "data" => {
        "priceRequests" => [
          { "id" => "1", "identifier" => { "id" => "0xabc" }, "proposedPrice" => "1", "resolvedPrice" => "1" },
          { "id" => "2", "identifier" => { "id" => "0xdef" }, "proposedPrice" => "1", "resolvedPrice" => "0" }
        ]
      }
    }
    res = response_double(stub_body)
    client = UmaClient.new(subgraph_url: "https://example.com/graphql")
    conn = Minitest::Mock.new
    conn.expect(:post, res, ["", Hash])
    client.instance_variable_set(:@conn, conn)

    result = client.fetch_price_requests

    assert_equal 2, result.size
    assert_equal "0xabc", result[0][:condition_id]
    assert_equal false, result[0][:disputed]
    assert_equal "0xdef", result[1][:condition_id]
    assert_equal true, result[1][:disputed]
    conn.verify
  end

  test "fetch_price_requests returns empty when subgraph returns no price requests" do
    stub_body = { "data" => { "priceRequests" => [] } }
    res = response_double(stub_body)
    client = UmaClient.new(subgraph_url: "https://example.com/graphql")
    conn = Minitest::Mock.new
    conn.expect(:post, res, ["", Hash])
    client.instance_variable_set(:@conn, conn)

    result = client.fetch_price_requests

    assert_equal [], result
    conn.verify
  end

  def response_double(body)
    res = Object.new
    res.define_singleton_method(:success?) { true }
    res.define_singleton_method(:status) { 200 }
    res.define_singleton_method(:body) { body }
    res
  end
end
