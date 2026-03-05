# frozen_string_literal: true

module Markets
  # Renders a single market card: category, question, risk badge + score, volume, end date.
  # Used on the markets index in a grid. Pass a Market record with risk_score loaded.
  class MarketCardComponent < ViewComponent::Base
    def initialize(market:)
      @market = market
    end

    def category
      @market.category.presence || "Uncategorized"
    end

    def risk_level
      @market.risk_score&.level.to_s.downcase
    end

    def risk_score_value
      @market.risk_score&.score
    end

    # Card-style risk pill: dot + label with /10 background and colored text
    def risk_pill_classes
      case risk_level
      when "low" then "bg-green-500/10 text-[#22c55e]"
      when "medium" then "bg-yellow-500/10 text-[#eab308]"
      when "high" then "bg-orange-500/10 text-[#f97316]"
      when "critical" then "bg-red-500/10 text-[#ef4444]"
      else "bg-[#1a1a1a] text-[#888888]"
      end
    end

    def risk_label
      return "—" if risk_level.blank?

      risk_level.capitalize
    end

    def formatted_volume
      return "—" unless @market.volume.present?

      num = @market.volume.to_f
      if num >= 1_000_000
        "$#{format('%.1f', num / 1_000_000)}M"
      elsif num >= 1_000
        "$#{format('%.0f', num / 1_000)}K"
      else
        "$#{num.to_i}"
      end
    end

    def formatted_end_date
      return "—" unless @market.end_date.present?

      "Ends #{@market.end_date.strftime('%b %d')}"
    end

    # Binary probability display: single source of truth from outcomes (first entry = Yes).
    # Falls back to yes_price for legacy rows or when outcomes are missing.
    def yes_probability_for_display
      return @market.yes_price.to_f if @market.yes_price.present?

      return nil unless @market.market_type == "binary" && @market.outcomes.is_a?(Array) && @market.outcomes.size >= 1

      o = @market.outcomes.first
      (o["probability"] || o[:probability] || o["price"] || o[:price])&.to_f
    end

    def binary_percentage
      return nil unless @market.market_type == "binary" && yes_probability_for_display.present?

      format("%.0f%%", yes_probability_for_display * 100)
    end

    def binary_bar_color
      return nil unless yes_probability_for_display.present?

      pct = yes_probability_for_display * 100
      if pct > 60
        "#22c55e"
      elsif pct >= 40
        "#eab308"
      else
        "#ef4444"
      end
    end

    # Multi-outcome: list of { label:, probability: } for display (supports string or symbol keys from jsonb).
    def multi_outcome_entries
      return [] unless @market.market_type == "multi_outcome" && @market.outcomes.is_a?(Array)

      @market.outcomes.filter_map do |o|
        prob = o["probability"] || o[:probability] || o["price"] || o[:price]
        next if prob.nil?

        label = (o["label"] || o[:label]).to_s.presence || "Option"
        { label: label, probability: prob.to_f }
      end
    end

    def multi_outcome_scrollable?
      multi_outcome_entries.size > 2
    end
  end
end
