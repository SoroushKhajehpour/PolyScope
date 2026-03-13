# frozen_string_literal: true

require "sidekiq/api"

# Orchestrates risk scoring for a single market (explicit user selection only).
class RiskScoreCalculationJob < ApplicationJob
  queue_as :default

  class << self
    # Enqueue only if no pending/running default-queue job exists for this market id.
    def enqueue_unique(market_id, session_key: nil)
      mid = market_id.to_i
      return if mid <= 0
      return if queued_or_running_for?(mid)

      perform_later(mid, session_key: session_key)
    end

    private

    def queued_or_running_for?(market_id)
      queue = Sidekiq::Queue.new("default")
      queue.any? do |job|
        next false unless job.klass == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
        args = job.args.first || {}
        next false unless args["job_class"] == name
        arguments = args["arguments"] || []
        arguments.first.to_i == market_id
      end
    rescue StandardError
      false
    end
  end

  def perform(market_id, session_key: nil)
    return unless market_id.present?

    process_market(Market.find_by(id: market_id), session_key: session_key)
  end

  private

  def process_market(market, session_key: nil)
    return if market.blank?
    return if market.resolution_criteria.to_s.strip.empty?

    RiskScorer.call(market, persist: true, session_key: session_key)
    risk_score = market.reload.risk_score
    return unless risk_score

    ActionCable.server.broadcast(
      "score_channel_#{market.id}",
      { event: "score_complete" }
    )
  rescue StandardError => e
    Rails.logger.warn("[RiskScoreCalculationJob] market_id=#{market.id} #{e.class}: #{e.message}")
  end
end
