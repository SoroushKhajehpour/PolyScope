# frozen_string_literal: true

class MarketsController < ApplicationController
  def index
    @markets = Market.includes(:risk_score).order(created_at: :desc)
  end
end