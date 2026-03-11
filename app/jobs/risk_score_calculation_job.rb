# frozen_string_literal: true
require "sidekiq/api"

# Orchestrates risk scoring: targeted run by market_id(s) or batch of markets needing scoring.
# Schedule: every 30m (config/sidekiq.yml). For each market: RiskScorer.call(market); errors logged and skipped.
class RiskScoreCalculationJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  class << self
    # Enqueue only if no pending/running default-queue job exists for this market id.
    def enqueue_unique(market_id)
      mid = market_id.to_i
      return if mid <= 0
      return if queued_or_running_for?(mid)

      perform_later(mid)
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

  # @param market_id [Integer, nil] Score one market
  # @param market_ids [Array<Integer>, nil] Score many markets
  # When both nil, select markets needing scoring (no score, stale, ending soon, or clarification added) and process up to BATCH_SIZE.
  def perform(market_id = nil, market_ids: nil)
    if market_id.present?
      process_market(Market.find_by(id: market_id))
      return
    end

    if market_ids.present?
      Market.where(id: market_ids).find_each { |m| process_market(m) }
      return
    end

    markets_needing_scoring.limit(BATCH_SIZE).find_each { |m| process_market(m) }
  end

  private

  def process_market(market)
    return if market.blank?

    RiskScorer.call(market, persist: true)
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

  def markets_needing_scoring
    t = Time.current
    window_end = 24.hours.from_now

    no_score = Market.left_joins(:risk_score).where(risk_scores: { id: nil })
    stale = Market.joins(:risk_score).where("markets.updated_at > risk_scores.computed_at")
    ending_soon = Market.where("end_date IS NOT NULL AND end_date >= ? AND end_date <= ?", t, window_end)
    clarification_after = Market.joins(:risk_score).joins(:clarifications).where("clarifications.created_at > risk_scores.computed_at").distinct

    ids = no_score.pluck(:id) | stale.pluck(:id) | ending_soon.pluck(:id) | clarification_after.pluck(:id)
    Market.where(id: ids)
  end
end
