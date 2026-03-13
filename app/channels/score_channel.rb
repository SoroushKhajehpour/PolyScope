# frozen_string_literal: true

class ScoreChannel < ApplicationCable::Channel
  def subscribed
    market_id = params[:market_id].to_i
    stream_from "score_channel_#{market_id}" if market_id > 0
  end

  def unsubscribed
    # No cleanup needed
  end
end
