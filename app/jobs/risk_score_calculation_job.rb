# frozen_string_literal: true
require "sidekiq/api"

# Orchestrates risk scoring: targeted run by market_id(s) or batch of markets needing scoring.
# For each market: RiskScorer.call(market); errors logged and skipped.
class RiskScoreCalculationJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

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

  # @param market_id [Integer, nil] Score one market (explicit user selection only)
  def perform(market_id = nil, session_key: nil, market_ids: nil)
    return unless market_id.present?

    process_market(Market.find_by(id: market_id), session_key: session_key)
  end

  private

  def process_market(market, session_key: nil)
    return if market.blank?
    return if market.resolution_criteria.to_s.strip.empty?

    # ✅ LLM/EMBEDDINGS CALL TRIGGER — only reachable from explicit user market selection
    # Do not move or duplicate this call elsewhere.
    RiskScorer.call(market, persist: true, session_key: session_key)
    risk_score = market.reload.risk_score
    return unless risk_score

    Turbo::StreamsChannel.broadcast_replace_to(
      "market_#{market.id}_score",
      target: "risk_score_result",
      partial: "markets/risk_score_result",
      locals: { market: market, risk_score: risk_score }
    )
  rescue StandardError => e
    Rails.logger.warn("[RiskScoreCalculationJob] market_id=#{market.id} #{e.class}: #{e.message}")
    # Skip; do not retry the whole batch
  end

  # Legacy batch scorer intentionally disabled to keep AI calls user-triggered only.
end
