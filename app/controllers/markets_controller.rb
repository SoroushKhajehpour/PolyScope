# frozen_string_literal: true

class MarketsController < ApplicationController
  VALID_RISK_LEVELS = %w[low medium high critical].freeze

  def index
    scope = Market.includes(:risk_score).order(created_at: :desc)
    if params[:risk].in?(VALID_RISK_LEVELS)
      scope = scope.references(:risk_scores).where(risk_scores: { level: params[:risk] })
    end
    @markets = scope
  end
end