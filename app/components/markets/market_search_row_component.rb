# frozen_string_literal: true

module Markets
  # Renders a compact row for one event in the live-search overlay. Title from event_question; no probability.
  class MarketSearchRowComponent < ViewComponent::Base
    def initialize(market:, total_volume: nil)
      @market = market
      @total_volume = total_volume
    end

    def row_title
      @market.event_question.presence || @market.question.presence || "Market"
    end

    def image_url
      @market.event_image.presence
    end

    def category
      @market.category.presence || nil
    end

    def detail_path
      "#"
    end
  end
end
