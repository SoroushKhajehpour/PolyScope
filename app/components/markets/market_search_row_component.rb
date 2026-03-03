# frozen_string_literal: true

module Markets
  # Renders a compact row for a single market in the live-search overlay.
  # Shows: optional icon/placeholder, truncated question, yes_price as %, optional category.
  # Links to market detail (or root for now until show exists).
  class MarketSearchRowComponent < ViewComponent::Base
    def initialize(market:)
      @market = market
    end

    def yes_percentage
      return "—" unless @market.yes_price.present?

      format("%.0f%%", (@market.yes_price.to_f * 100))
    end

    def category
      @market.category.presence || nil
    end

    def detail_path
      # TODO: replace with market_path(@market) when market show route exists
      "#"
    end
  end
end
