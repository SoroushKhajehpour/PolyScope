# frozen_string_literal: true

module Markets
  # Renders a single event card: category, title (event_question), risk badge, volume, end date.
  # One card per event; no outcome/probability UI.
  class MarketCardComponent < ViewComponent::Base
    def initialize(market:, total_volume: nil)
      @market = market
      @total_volume = total_volume
    end

    def category
      @market.category.presence || "Uncategorized"
    end

    def card_title
      @market.event_question.presence || @market.question.presence || "Market"
    end

    def image_url
      @market.event_image.presence
    end

    def risk_level
      @market.risk_score&.level.to_s.downcase
    end

    def risk_score_value
      @market.risk_score&.score
    end

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

    def display_volume
      vol = @total_volume || @market.volume
      return "—" unless vol.present?
      num = vol.to_f
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
  end
end
