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
            explanation: explanation_for(factor_key, values[:score], market_type, market)
          }
        end

        {
          summary: summary_for(score, market_type),
          factors: factors,
          topRiskDrivers: top_risk_drivers(factors),
          whyNotHigherRisk: why_not_higher_risk(factors, market_type),
          confidenceNote: confidence[:note],
          liquidityNote: liquidity_note_for(liquidity_risk),
          resolutionCriteria: resolution_criteria_card(market, resolution_analysis)
        }
      end

      private

      def summary_for(score, market_type)
        if score <= 25
          "This market carries LOW risk because the outcome appears objectively verifiable with clear resolution criteria."
        elsif score <= 50
          "This market carries MODERATE risk because key outcomes are verifiable, but timing and context still add uncertainty."
        elsif score <= 75
          "This market carries HIGH risk because one or more major factors increase uncertainty and manipulation exposure."
        else
          "This market carries VERY HIGH risk due to substantial ambiguity, uncertainty, or susceptibility to manipulation."
        end + " Market type detected: #{market_type}."
      end

      def impact_for(score)
        return "Very Low" if score <= 20
        return "Low" if score <= 40
        return "Moderate" if score <= 60
        return "High" if score <= 80

        "Very High"
      end

      def top_risk_drivers(factors)
        factors
          .sort_by { |f| -f[:score] }
          .first(3)
          .select { |f| f[:score] >= 45 }
          .map { |f| "#{f[:label]} contributes elevated risk (#{f[:score]}/100)." }
      end

      def why_not_higher_risk(factors, market_type)
        reasons = factors
          .sort_by { |f| f[:score] }
          .first(3)
          .select { |f| f[:score] <= 30 }
          .map { |f| "#{f[:label]} remains relatively low (#{f[:score]}/100)." }

        if %w[CRYPTO_PRICE SPORTS_OUTCOME].include?(market_type)
          reasons << "Outcome type is typically binary and objectively verifiable."
        end
        reasons.uniq
      end

      def explanation_for(factor_key, score, market_type, market)
        case factor_key
        when :resolution_clarity
          "Resolution criteria clarity is scored at #{score}/100 for market type #{market_type}."
        when :time_horizon
          "Longer time to resolution increases uncertainty; this market scores #{score}/100."
        when :historical_accuracy
          "Historical resolution reliability for similar markets maps to #{score}/100."
        when :manipulation_risk
          "Market structure and source profile imply manipulation risk of #{score}/100."
        when :information_asymmetry
          "Potential insider or uneven information access is estimated at #{score}/100."
        else
          "Factor score is #{score}/100."
        end
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
          sourceLabel: analysis[:from_fallback] ? "Estimated (AI unavailable)" : "Analysis by OpenAI · cached 24h"
        }
      end
    end
  end
end
