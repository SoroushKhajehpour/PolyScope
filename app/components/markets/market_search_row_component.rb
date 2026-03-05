# frozen_string_literal: true

module Markets
  # Renders a compact row for a single market in the live-search overlay.
  # Shows: optional icon/placeholder, truncated question, binary % from outcomes (fallback yes_price), optional category.
  # Links to market detail (or root for now until show exists).
  class MarketSearchRowComponent < ViewComponent::Base
    def initialize(market:)
      @market = market
    end

    # Binary Yes %: from first outcome when present, else yes_price for backward compatibility.
    def yes_percentage
      prob = yes_probability_for_display
      return "—" unless prob.present?

      format("%.0f%%", prob * 100)
    end

    def category
      @market.category.presence || nil
    end

    def detail_path
      # TODO: replace with market_path(@market) when market show route exists
      "#"
    end

    private

    def yes_probability_for_display
      return @market.yes_price.to_f if @market.yes_price.present?

      return nil unless @market.market_type == "binary" && @market.outcomes.is_a?(Array) && @market.outcomes.size >= 1

      o = @market.outcomes.first
      (o["probability"] || o[:probability] || o["price"] || o[:price])&.to_f
    end
  end
end
