# frozen_string_literal: true

require "test_helper"

class RiskScoreCalculationJobTest < ActiveSupport::TestCase
  test "enqueue_unique enqueues when no duplicate pending" do
    queue = Object.new
    queue.define_singleton_method(:any?) { |_blk| false }

    called = []
    Sidekiq::Queue.stub(:new, queue) do
      RiskScoreCalculationJob.stub(:perform_later, ->(mid) { called << mid }) do
        RiskScoreCalculationJob.enqueue_unique(123)
      end
    end

    assert_equal [123], called
  end

  test "enqueue_unique skips duplicate pending job for market" do
    wrapped_args = {
      "job_class" => "RiskScoreCalculationJob",
      "arguments" => [123]
    }
    fake_job = Struct.new(:klass, :args).new("ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper", [wrapped_args])
    queue = Object.new
    queue.define_singleton_method(:any?) { |&blk| blk.call(fake_job) }

    called = []
    Sidekiq::Queue.stub(:new, queue) do
      RiskScoreCalculationJob.stub(:perform_later, ->(mid) { called << mid }) do
        RiskScoreCalculationJob.enqueue_unique(123)
      end
    end

    assert_empty called
  end

  test "perform with market_id creates or updates risk_score" do
    market = Market.create!(
      event_id: "e1",
      event_question: "Q?",
      condition_id: "0x1",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )
    RiskScoreCalculationJob.perform_now(market.id)
    record = RiskScore.find_by(market: market)
    assert record
    assert record.score.between?(0, 100)
    assert record.computed_at.present?
  end

  test "perform with market_ids processes each market" do
    m1 = Market.create!(event_id: "e1", event_question: "Q1", condition_id: "0x1", category: "Politics", status: "active", resolution_criteria: "Source: official.")
    m2 = Market.create!(event_id: "e2", event_question: "Q2", condition_id: "0x2", category: "Crypto", status: "active", resolution_criteria: "Date: 2025-06-01.")
    RiskScoreCalculationJob.perform_now(m1.id)
    RiskScoreCalculationJob.perform_now(m2.id)
    assert RiskScore.exists?(market: m1)
    assert RiskScore.exists?(market: m2)
  end

  test "perform with no args runs without error" do
    RiskScoreCalculationJob.perform_now
  end

  test "perform with invalid market_id does not raise" do
    RiskScoreCalculationJob.perform_now(0)
  end

  test "perform broadcasts turbo stream after scoring" do
    market = Market.create!(
      event_id: "e-broadcast",
      event_question: "Q?",
      condition_id: "0x99",
      category: "Politics",
      status: "active",
      resolution_criteria: "Resolved by official source."
    )

    fake_result = { score: 37, level: "medium" }
    broadcast_calls = []

    fake_call = lambda do |m, persist: true, session_key: nil|
      m.risk_score || m.create_risk_score!(score: 37, level: "medium", factors: {}, computed_at: Time.current)
      fake_result
    end

    RiskScorer.stub(:call, fake_call) do
      Turbo::StreamsChannel.stub(:broadcast_replace_to, ->(*args, **kwargs) { broadcast_calls << [args, kwargs] }) do
        RiskScoreCalculationJob.perform_now(market.id)
      end
    end

    assert_equal 1, broadcast_calls.size
    args, kwargs = broadcast_calls.first
    assert_equal "market_#{market.id}_score", args.first
    assert_equal "risk_score_result", kwargs[:target]
    assert_equal "markets/risk_score_result", kwargs[:partial]
  end
end
