# frozen_string_literal: true

module Markets
  # Renders the markets index filter bar: risk level pills + search input.
  # Optional selected_risk: "all" | "low" | "medium" | "high" | "critical" for the active pill.
  class MarketFiltersComponent < ViewComponent::Base
    RISK_OPTIONS = %w[all low medium high critical].freeze

    def initialize(selected_risk: "all", query: nil)
      @selected_risk = selected_risk.to_s.downcase
      @selected_risk = "all" unless RISK_OPTIONS.include?(@selected_risk)
      @query = query.to_s
    end

    def active?(option)
      @selected_risk == option
    end

    # Risk colors (match RiskBadgeComponent): low green, medium amber, high orange, critical red.
    PILL_COLORS = {
      "all" => { bg: "bg-[#1a1a1a]", text: "text-[#888888]" },
      "low" => { bg: "bg-[#22c55e15]", text: "text-[#22c55e]" },
      "medium" => { bg: "bg-[#eab30815]", text: "text-[#eab308]" },
      "high" => { bg: "bg-[#f9731615]", text: "text-[#f97316]" },
      "critical" => { bg: "bg-[#ef444415]", text: "text-[#ef4444]" }
    }.freeze

    def pill_classes(option)
      base = "rounded-full border-0 px-3 py-1.5 text-xs font-medium transition-colors"
      if active?(option)
        "#{base} bg-[#3b82f6] text-white"
      else
        c = PILL_COLORS[option] || PILL_COLORS["all"]
        "#{base} #{c[:bg]} #{c[:text]} hover:opacity-90"
      end
    end

    def filter_path(option)
      option == "all" ? helpers.root_path : helpers.root_path(risk: option)
    end
  end
end
