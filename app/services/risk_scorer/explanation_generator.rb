# frozen_string_literal: true

module RiskScorer
  class ExplanationGenerator
    FACTOR_LABELS = {
      resolution_clarity: "Resolution Clarity",
      time_horizon: "Time Horizon",
      historical_accuracy: "Historical Accuracy",
      manipulation_risk: "Manipulation Risk",
      information_asymmetry: "Information Asymmetry"
    }.freeze

    class << self
      def call(market:, market_type:, breakdown:, score:, liquidity_risk:, confidence:, resolution_analysis:)
        factors = breakdown.map do |factor_key, values|
          {
            label: FACTOR_LABELS[factor_key],
            score: values[:score].round,
            maxScore: 100,
            weight: "#{(values[:weight] * 100).round}%",
            impact: impact_for(values[:score]),
            explanation: explanation_for(factor_key, values[:score], market_type, market, resolution_analysis)
          }
        end

        {
          summary: summary_for(score, market_type, resolution_analysis),
          factors: factors,
          topRiskDrivers: top_risk_drivers(factors),
          whyNotHigherRisk: why_not_higher_risk(factors, market_type),
          confidenceNote: confidence[:note],
          confidenceExplanation: confidence_explanation(confidence, resolution_analysis),
          liquidityNote: liquidity_note_for(liquidity_risk),
          resolutionCriteria: resolution_criteria_card(market, resolution_analysis)
        }
      end

      private

      def summary_for(score, market_type, resolution_analysis = {})
        if !resolution_analysis[:from_fallback] && resolution_analysis[:overallNote].present?
          return resolution_analysis[:overallNote]
        end

        if score <= 39
          "This market carries LOW risk because the outcome appears objectively verifiable with clear resolution criteria."
        elsif score <= 69
          "This market carries MEDIUM risk because key outcomes are verifiable, but timing and context still add uncertainty."
        else
          "This market carries HIGH risk because one or more major factors increase uncertainty and manipulation exposure."
        end + " Market type detected: #{market_type}."
      end

      def impact_for(score)
        return "Low" if score <= 39
        return "Medium" if score <= 69

        "High"
      end

      def top_risk_drivers(factors)
        factors
          .sort_by { |f| -f[:score] }
          .first(3)
          .select { |f| f[:score] >= 40 }
          .map { |f| "#{f[:label]} contributes elevated risk (#{f[:score]}/100)." }
      end

      def why_not_higher_risk(factors, market_type)
        reasons = factors
          .sort_by { |f| f[:score] }
          .first(3)
          .select { |f| f[:score] <= 39 }
          .map { |f| "#{f[:label]} remains relatively low (#{f[:score]}/100)." }

        if %w[CRYPTO_PRICE SPORTS_OUTCOME].include?(market_type)
          reasons << "Outcome type is typically binary and objectively verifiable."
        end
        reasons.uniq
      end

      def explanation_for(factor_key, score, market_type, market, resolution_analysis = {})
        llm_explanation = resolution_analysis.dig(:factorExplanations, factor_key) ||
                          resolution_analysis.dig(:factorExplanations, factor_key.to_s)

        tier = if score >= 70 then :high elsif score >= 40 then :medium else :low end
        fallback = FALLBACK_EXPLANATIONS.dig(factor_key, tier) || "Factor score is #{score}/100."

        return llm_explanation if llm_explanation.present?

        fallback
      end

      FALLBACK_EXPLANATIONS = {
        resolution_clarity: {
          high: "This market's resolution criteria contains language open to interpretation, increasing the risk of disputed outcomes.",
          medium: "The resolution criteria is mostly clear but includes some terms that could be read in more than one way.",
          low: "Resolution criteria are well-defined and objectively verifiable, minimizing dispute risk."
        },
        time_horizon: {
          high: "This market resolves far in the future, leaving significant room for unexpected developments and shifting conditions.",
          medium: "The resolution timeline is medium-range, introducing some uncertainty from evolving circumstances.",
          low: "This market resolves relatively soon, limiting the window for unexpected changes."
        },
        historical_accuracy: {
          high: "Similar markets have historically resolved in unpredictable or disputed ways, suggesting elevated outcome risk.",
          medium: "Historical data for comparable markets shows mixed reliability, warranting medium caution.",
          low: "Past markets of this type have generally resolved cleanly and as expected."
        },
        manipulation_risk: {
          high: "This market's structure and thin participation make it notably vulnerable to price manipulation or wash trading.",
          medium: "Some aspects of this market's structure could be exploited, though manipulation risk is not dominant.",
          low: "Market structure and participation levels make manipulation unlikely under normal conditions."
        },
        information_asymmetry: {
          high: "Insiders or specialists likely have material information advantages, creating significant risk for typical participants.",
          medium: "Some participants may have better access to relevant information, introducing a medium edge imbalance.",
          low: "Relevant information is broadly available, limiting the advantage any single participant could hold."
        }
      }.freeze

      def confidence_explanation(confidence, resolution_analysis)
        tier = confidence[:tier].to_s
        missing = confidence[:missing_sources] || []
        llm_available = !resolution_analysis[:from_fallback]

        parts = []
        case tier
        when "high"
          parts << "All primary data sources contributed to this score."
          parts << "AI analysis confirmed the ambiguity assessment." if llm_available
        when "medium"
          if missing.any?
            parts << "Score confidence is moderate because #{missing.join(' and ')} could not be factored in."
          else
            parts << "Score confidence is moderate — the available data provides a reasonable but incomplete picture."
          end
        when "low"
          if missing.length >= 2
            parts << "Confidence is low because multiple data sources were unavailable: #{missing.join(', ')}."
          elsif missing.any?
            parts << "Confidence is low because #{missing.first} was unavailable."
          else
            parts << "Confidence is low due to limited data availability for this market."
          end
        end

        parts << "AI-powered resolution analysis was not available for this evaluation." unless llm_available
        parts.join(" ")
      end

      def liquidity_note_for(score)
        numeric = score.to_i.clamp(0, 100)
        label = if numeric <= 30
          "HIGH_LIQUIDITY"
        elsif numeric <= 60
          "MODERATE_LIQUIDITY"
        else
          "LOW_LIQUIDITY"
        end
        explanation = case label
        when "HIGH_LIQUIDITY"
          "This market has high trading volume. It is generally easier to enter and exit positions."
        when "MODERATE_LIQUIDITY"
          "This market has moderate trading volume. Some slippage may occur for larger orders."
        else
          "This market has low trading volume. Large orders may face noticeable slippage."
        end
        { score: numeric, label: label, explanation: explanation }
      end

      def resolution_criteria_card(market, analysis)
        criteria_text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s : ""
        {
          criteriaText: criteria_text,
          hasAmbiguity: !!analysis[:hasAmbiguity],
          ambiguityLevel: analysis[:ambiguityLevel].to_s.upcase,
          misinterpretations: Array(analysis[:misinterpretations]),
          overallNote: analysis[:overallNote].to_s,
          sourceLabel: analysis[:from_fallback] ? "Estimated (AI unavailable)" : "Analysis by Anthropic · cached 24h"
        }
      end
    end
  end
end
