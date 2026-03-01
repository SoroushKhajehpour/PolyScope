# frozen_string_literal: true

module Markets
  # Renders a small colored badge for risk level (Low / Medium / High / Critical).
  # Use with RiskBadgeComponent.new(level: market.risk_score&.level)
  class RiskBadgeComponent < ViewComponent::Base
    VALID_LEVELS = %w[low medium high critical].freeze

    def initialize(level: nil)
      @level = level.to_s.downcase.presence
      @level = nil unless VALID_LEVELS.include?(@level)
    end

    def label
      return "—" if @level.blank?

      @level.capitalize
    end

    def color_class
      case @level
      when "low" then "bg-risk-low text-background"
      when "medium" then "bg-risk-medium text-background"
      when "high" then "bg-risk-high text-background"
      when "critical" then "bg-risk-critical text-background"
      else "bg-border text-text-secondary"
      end
    end

    def render?
      true
    end
  end
end
