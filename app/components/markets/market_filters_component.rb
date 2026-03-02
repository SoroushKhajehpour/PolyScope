# frozen_string_literal: true

module Markets
  # Renders the markets index filter bar: risk level pills + search input.
  # Optional selected_risk: "all" | "low" | "medium" | "high" | "critical" for the active pill.
  class MarketFiltersComponent < ViewComponent::Base
    RISK_OPTIONS = %w[all low medium high critical].freeze

    def initialize(selected_risk: "all")
      @selected_risk = selected_risk.to_s.downcase
      @selected_risk = "all" unless RISK_OPTIONS.include?(@selected_risk)
    end

    def active?(option)
      @selected_risk == option
    end

    def pill_classes(option)
      if active?(option)
        "rounded-full border border-transparent bg-[#3b82f6] px-3 py-1.5 text-xs font-medium text-white"
      else
        "rounded-full border border-[#2a2a2a] bg-[#1a1a1a] px-3 py-1.5 text-xs font-medium text-[#888888] transition-colors hover:border-[#3b82f6] hover:text-white"
      end
    end

    def filter_path(option)
      option == "all" ? helpers.root_path : helpers.root_path(risk: option)
    end
  end
end
