# frozen_string_literal: true

module Markets
  # Renders one card for an event group: title, category/image from first market,
  # list of sub-markets (question, probability, volume), total volume, end date.
  # Pass markets (same group_id) and optional title (derived from first market question if blank).
  class EventGroupCardComponent < ViewComponent::Base
    def initialize(markets:, title: nil)
      @markets = markets.to_a
      @title = title.presence || @markets.first&.question || "Event"
    end

    def first_market
      @markets.first
    end

    def category
      first_market&.category.presence || "Uncategorized"
    end

    def total_volume
      @markets.sum { |m| m.volume.to_f }
    end

    def formatted_total_volume
      return "—" if total_volume.zero?
      if total_volume >= 1_000_000
        "$#{format('%.1f', total_volume / 1_000_000)}M"
      elsif total_volume >= 1_000
        "$#{format('%.0f', total_volume / 1_000)}K"
      else
        "$#{total_volume.to_i}"
      end
    end

    def formatted_end_date
      return "—" unless first_market&.end_date.present?
      "Ends #{first_market.end_date.strftime('%b %d')}"
    end

    def scrollable?
      @markets.size > 4
    end

    # One row per market: { question:, probability_text:, formatted_volume: }
    def market_rows
      @markets.map do |m|
        {
          question: m.question.to_s.truncate(60),
          probability_text: probability_for_market(m),
          formatted_volume: formatted_volume_for(m)
        }
      end
    end

    private

    def probability_for_market(market)
      prob = market.yes_price.to_f if market.yes_price.present?
      if prob.nil? && market.market_type == "binary" && market.outcomes.is_a?(Array) && market.outcomes.size >= 1
        o = market.outcomes.first
        prob = (o["probability"] || o[:probability] || o["price"] || o[:price])&.to_f
      end
      return "—" if prob.nil?
      format("%.0f%%", prob * 100)
    end

    def formatted_volume_for(market)
      return "—" unless market.volume.present?
      num = market.volume.to_f
      if num >= 1_000_000
        "$#{format('%.1f', num / 1_000_000)}M"
      elsif num >= 1_000
        "$#{format('%.0f', num / 1_000)}K"
      else
        "$#{num.to_i}"
      end
    end
  end
end
