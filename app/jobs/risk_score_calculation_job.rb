# frozen_string_literal: true

# Orchestrates risk scoring for a single market (explicit user selection only).
class RiskScoreCalculationJob < ApplicationJob
  queue_as :default

  def perform(market_id, session_key: nil)
    return unless market_id.present?

    process_market(Market.find_by(id: market_id), session_key: session_key)
  end

  private

  def process_market(market, session_key: nil)
    mid = market&.id
    begin
      if market.blank? || market.resolution_criteria.to_s.strip.empty?
        return
      end

      me = market.market_embedding
      if me.blank? || me.embedding_vector.blank?
        MarketEmbeddingJob.perform_now(market.id, session_key: session_key)
        market.reload
      end

      effective_session = session_key.presence || "sidekiq_market_#{market.id}"
      RiskScorer.call(market, persist: true, session_key: effective_session)
      risk_score = market.reload.risk_score
      unless risk_score
        RiskScorer.persist_error_fallback!(market, error: "RiskScorer returned without persisting a score")
        risk_score = market.reload.risk_score
      end

      return unless risk_score

      ActionCable.server.broadcast(
        "score_channel_#{market.id}",
        { event: "score_complete" }
      )
    rescue StandardError => e
      Rails.logger.error(
        "[RiskScoreCalculationJob] FAILED market_id=#{mid} #{e.class}: #{e.message}\n#{Array(e.backtrace).first(15).join("\n")}"
      )
      RiskScorer.persist_error_fallback!(market, error: e) if market&.persisted?
    end
  end
end
