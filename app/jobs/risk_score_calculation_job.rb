# frozen_string_literal: true

# Orchestrates risk scoring for a single market (explicit user selection only).
class RiskScoreCalculationJob < ApplicationJob
  queue_as :default

  def perform(market_id, session_key: nil)
    return unless market_id.present?

    market = Market.includes(:market_embedding).find_by(id: market_id)
    process_market(market, session_key: session_key)
  end

  private

  def process_market(market, session_key: nil)
    mid = market&.id
    begin
      if market.blank?
        return
      end

      if market.resolution_criteria.to_s.strip.empty?
        Rails.logger.warn("[RiskScoreCalculationJob] skip scoring market_id=#{mid}: blank resolution_criteria")
        RiskScorer.persist_error_fallback!(market, error: "Resolution criteria missing; cannot run risk analysis.")
        broadcast_score_ready(market)
        return
      end

      begin
        me = market.market_embedding
        if me.blank? || me.embedding_vector.blank?
          MarketEmbeddingJob.perform_now(market.id, session_key: session_key)
          market.reload
        end
      rescue StandardError => e
        # OpenAI/embeddings are optional; Claude-only scoring must still run.
        Rails.logger.warn("[RiskScoreCalculationJob] embedding step failed (continuing): #{e.class}: #{e.message}")
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

      broadcast_score_ready(market)
    rescue StandardError => e
      Rails.logger.error(
        "[RiskScoreCalculationJob] FAILED market_id=#{mid} #{e.class}: #{e.message}\n#{Array(e.backtrace).first(15).join("\n")}"
      )
      if market&.persisted?
        RiskScorer.persist_error_fallback!(market, error: e)
        broadcast_score_ready(market)
      end
    end
  end

  def broadcast_score_ready(market)
    return unless market&.id

    ActionCable.server.broadcast(
      "score_channel_#{market.id}",
      { event: "score_complete" }
    )
  end
end
