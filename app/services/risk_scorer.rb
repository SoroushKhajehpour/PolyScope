# frozen_string_literal: true

# RISK SCORING FORMULA — READ BEFORE MODIFYING
#
# Formula:
#   total = (resolution_clarity × 0.38) + (time_horizon × 0.17)
#         + (historical_accuracy × 0.18) + (manipulation_risk × 0.17)
#         + (information_asymmetry × 0.10)
#
# resolution_clarity = (type_base × type_base_weight) + (ambiguity_text_score × (1 - type_base_weight))
#   └─ ambiguity_text_score can be overridden by LLM misinterpretation analysis
#      (NONE -> floor 15, HIGH -> floor 75)
#
# Liquidity is computed but NOT included in total_score. It is returned as
# a separate parallel signal: liquidity_risk.
#
# External API calls:
#   1. Anthropic (via LlmClient) — ResolutionMisinterpretationAnalyzer, SourceDependencyScorer
#   2. OpenAI — Embeddings only (SimilarOutcomesScorer / MarketEmbeddingJob)
#
# All calls are cache-first (24h), explicit-select trigger only, dedup locked,
# budget-limited, and fallback-safe.
#
# Market type source:
#   1) LLM from ResolutionMisinterpretationAnalyzer (preferred)
#   2) config/risk_scoring.yml -> market_type_fallback_by_category (fallback only)
#
# Override gates:
#   - known manipulated source + manipulation_risk >= threshold -> floor score
#   - missing resolution_criteria -> floor score
module RiskScorer
  AMBIGUITY_REGEX_SCALE = 4
  DISPUTE_RATE_MULTIPLIER = 5.0
  SIMILAR_OUTCOMES_MULTIPLIER = 10.0
  THIN_MARKET_VOLUME_THRESHOLD = 50_000

  FACTOR_WEIGHTS = {
    resolution_clarity: 0.38,
    time_horizon: 0.17,
    historical_accuracy: 0.18,
    manipulation_risk: 0.17,
    information_asymmetry: 0.10
  }.freeze

  FACTOR_NAME_MAP = {
    resolution_clarity: :f1_ambiguity,
    information_asymmetry: :f2_source_dep,
    manipulation_risk: :f3_dispute_rate,
    time_horizon: :f4_time_spec,
    liquidity: :f5_liquidity,
    historical_accuracy: :f6_historical_accuracy
  }.freeze

  HISTORICAL_ACCURACY_TYPE_BASE = {
    "CRYPTO_PRICE" => 20,
    "SPORTS_OUTCOME" => 22,
    "ELECTION_POLITICAL" => 38,
    "MACRO_ECONOMIC" => 35,
    "GEOPOLITICAL" => 55,
    "SUBJECTIVE_QUALITATIVE" => 65
  }.freeze

  LEVEL_BANDS = [
    [0, 39, "low"],
    [40, 69, "medium"],
    [70, 100, "high"]
  ].freeze

  class << self
    def call(market, persist: true, session_key: nil)
      resolution_analysis = RiskScorer::ResolutionMisinterpretationAnalyzer.call(market, session_key: session_key)
      market_type_result = resolve_market_type(market, resolution_analysis)
      market_type = market_type_result[:market_type]
      source_result = RiskScorer::SourceDependencyScorer.call(market)
      similar_result = RiskScorer::SimilarOutcomesScorer.call(market)
      liquidity_risk = liquidity_score(market)
      breakdown = compute_breakdown(
        market: market,
        market_type: market_type,
        market_type_confidence: market_type_result[:confidence],
        resolution_analysis: resolution_analysis,
        source_result: source_result,
        similar_result: similar_result
      )
      total = weighted_score(breakdown)
      gate = apply_override_gates(total, breakdown, market)
      score = gate[:score]
      level = level_for(score)

      data_availability = {
        llm_available: !resolution_analysis[:from_fallback],
        embeddings_available: similar_result[:available],
        resolution_criteria: market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s : "",
        market_type_confidence: market_type_result[:confidence]
      }
      confidence = confidence_tier_for(score, data_availability)
      explanation = RiskScorer::ExplanationGenerator.call(
        market: market,
        market_type: market_type,
        breakdown: breakdown,
        score: score,
        liquidity_risk: liquidity_risk,
        confidence: confidence,
        resolution_analysis: resolution_analysis
      )

      unavailable_sources = confidence[:missing_sources].dup

      result = {
        score: score,
        level: level,
        market_type: market_type.to_s.upcase.to_sym,
        market_type_source: market_type_result[:source],
        resolution_clarity_base: breakdown.dig(:resolution_clarity, :base),
        type_base_weight: breakdown.dig(:resolution_clarity, :type_base_weight),
        factors: breakdown.transform_values { |v| v[:score].round },
        liquidity_risk: liquidity_risk,
        confidence_tier: confidence[:tier].to_s,
        confidence_note: confidence[:note],
        factors_imputed: [],
        override_gate_applied: gate[:applied],
        factor_metadata: {
          market_type: market_type,
          market_type_source: market_type_result[:source],
          market_type_reasoning: market_type_result[:reasoning],
          market_type_confidence: market_type_result[:confidence],
          breakdown: breakdown.transform_values { |v| v.transform_keys(&:to_s) },
          explanation: explanation,
          resolution_analysis: resolution_analysis,
          confidence: confidence,
          data_sources_unavailable: unavailable_sources,
          similar_outcomes: similar_result[:factor_metadata] || {}
        }
      }

      persist_risk_score!(market, result) if persist && market.respond_to?(:id) && market.id.present?
      result
    end

    # Always persist something when full scoring fails so the market page is never empty-handed.
    def persist_error_fallback!(market, error:)
      return unless market&.id.present?

      err = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
      resolution_analysis = { from_fallback: true, fallback_reason: "scoring_error" }
      explanation = {
        summary: "Provisional risk estimate. Full analysis did not complete.",
        confidenceNote: err.truncate(500),
        confidenceExplanation: "Set ANTHROPIC_API_KEY (Claude) and OPENAI_API_KEY (embeddings) on the server, then reload. Check logs for details.",
        factors: [],
        topRiskDrivers: ["Automated analysis failed or returned no score."],
        whyNotHigherRisk: [],
        resolutionCriteria: {
          criteriaText: market.resolution_criteria.to_s.truncate(500).presence,
          hasAmbiguity: true,
          ambiguityLevel: "UNKNOWN",
          misinterpretations: [],
          overallNote: "Unable to run full resolution analysis.",
          sourceLabel: nil
        },
        liquidityNote: { label: "Liquidity", explanation: "—" }
      }
      result = {
        score: 50,
        level: "medium",
        market_type: :SUBJECTIVE_QUALITATIVE,
        market_type_source: :error_fallback,
        resolution_clarity_base: 50,
        type_base_weight: 0.5,
        factors: {
          resolution_clarity: 50,
          time_horizon: 50,
          historical_accuracy: 50,
          manipulation_risk: 50,
          information_asymmetry: 50
        },
        liquidity_risk: 50,
        confidence_tier: "low",
        confidence_note: err.truncate(500),
        factors_imputed: [],
        override_gate_applied: "error_fallback",
        factor_metadata: {
          scoring_fallback: true,
          scoring_error: err.truncate(500),
          resolution_analysis: resolution_analysis,
          explanation: explanation,
          confidence: { tier: "low", missing_sources: ["anthropic", "openai"] },
          data_sources_unavailable: %w[anthropic openai],
          similar_outcomes: {}
        }
      }
      persist_risk_score!(market, result)
    rescue StandardError => e
      Rails.logger.error("[RiskScorer] persist_error_fallback! failed: #{e.class}: #{e.message}")
    end

    private

    def compute_breakdown(market:, market_type:, market_type_confidence:, resolution_analysis:, source_result:, similar_result:)
      llm_scores = resolution_analysis[:factorScores] if !resolution_analysis[:from_fallback]
      clarity = resolution_clarity_components(market, market_type, market_type_confidence, resolution_analysis)

      breakdown = {
        resolution_clarity: {
          score: clarity[:score],
          base: clarity[:base],
          type_base_weight: clarity[:type_base_weight],
          weight: FACTOR_WEIGHTS[:resolution_clarity]
        },
        time_horizon: {
          score: time_horizon_score(market),
          weight: FACTOR_WEIGHTS[:time_horizon]
        },
        historical_accuracy: {
          score: historical_accuracy_score(market, market_type, similar_result),
          weight: FACTOR_WEIGHTS[:historical_accuracy]
        },
        manipulation_risk: {
          score: manipulation_risk_score(market, market_type, source_result),
          weight: FACTOR_WEIGHTS[:manipulation_risk]
        },
        information_asymmetry: {
          score: information_asymmetry_score(market, market_type, source_result),
          weight: FACTOR_WEIGHTS[:information_asymmetry]
        }
      }

      if llm_scores.is_a?(Hash)
        breakdown.each_key do |factor_key|
          llm_val = llm_scores[factor_key]
          if llm_val.is_a?(Integer) && llm_val.between?(0, 100)
            breakdown[factor_key][:score] = llm_val
          end
        end

        fix_inverted_clarity!(breakdown, resolution_analysis)
      end

      breakdown
    end

    def fix_inverted_clarity!(breakdown, resolution_analysis)
      clarity_score = breakdown[:resolution_clarity][:score]
      ambiguity = resolution_analysis[:ambiguityLevel].to_s.upcase

      if ambiguity == "HIGH" && clarity_score < 40
        breakdown[:resolution_clarity][:score] = (100 - clarity_score).clamp(60, 95)
      elsif ambiguity == "MODERATE" && clarity_score < 25
        breakdown[:resolution_clarity][:score] = (100 - clarity_score).clamp(45, 80)
      elsif ambiguity == "NONE" && clarity_score > 60
        breakdown[:resolution_clarity][:score] = (100 - clarity_score).clamp(5, 35)
      end
    end

    def weighted_score(breakdown)
      raw = breakdown.sum { |_name, v| v[:score].to_f * v[:weight].to_f }
      raw.round.clamp(0, 100)
    end

    def level_for(score)
      LEVEL_BANDS.each do |min, max, label|
        return label if score >= min && score <= max
      end
      "medium"
    end

    def resolution_clarity_components(market, market_type, market_type_confidence, resolution_analysis)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s : ""
      if text.strip.empty?
        return { score: 95, base: 95, type_base_weight: type_base_weight_for(market_type_confidence) }
      end

      base = case market_type
      when "CRYPTO_PRICE" then 10
      when "SPORTS_OUTCOME" then 14
      when "ELECTION_POLITICAL" then 45
      when "MACRO_ECONOMIC" then 50
      when "GEOPOLITICAL" then 80
      else 85
      end

      ambiguity_text_score = (RiskScorer::AmbiguityRegexScorer.call(text) * AMBIGUITY_REGEX_SCALE).to_f.clamp(0, 100)

      ambiguity_override = case resolution_analysis[:ambiguityLevel].to_s.upcase
      when "HIGH" then [ambiguity_text_score, 75].max
      when "NONE" then [ambiguity_text_score, 15].min
      else ambiguity_text_score
      end

      type_weight = type_base_weight_for(market_type_confidence)
      adjusted = (base * type_weight) + (ambiguity_override * (1.0 - type_weight))
      {
        score: adjusted.round.clamp(0, 100),
        base: base,
        type_base_weight: type_weight
      }
    end

    def time_horizon_score(market)
      return 60 unless market.respond_to?(:end_date) && market.end_date.present?

      days = ((market.end_date.to_time - Time.current) / 1.day).round
      return 80 if days > 365
      return 65 if days > 180
      return 50 if days > 90
      return 35 if days > 30
      return 20 if days > 7

      10
    end

    def liquidity_score(market)
      vol = market.respond_to?(:volume) ? market.volume.to_f : 0.0
      return 80 if vol <= 0
      return 10 if vol >= 5_000_000
      return 20 if vol >= 1_000_000
      return 35 if vol >= 250_000
      return 50 if vol >= 50_000
      return 65 if vol >= 10_000

      80
    end

    # historical_accuracy sub-score composition:
    #   60% — market type base (20–70): prior expectation of accuracy by category
    #   25% — dispute rate (DisputeRateScorer × 5): UMA on-chain dispute history
    #   15% — similar outcomes (SimilarOutcomesScorer × 10): embedding-matched markets
    #
    # Rationale: type base dominates when embeddings are unavailable; dispute rate
    # is more reliable than similar-markets signal and weighted higher accordingly.
    # To retune: adjust multipliers so they continue to sum to 100% of sub-score range.
    def historical_accuracy_score(market, market_type, similar_result)
      type_base = HISTORICAL_ACCURACY_TYPE_BASE.fetch(market_type.to_s, 65)

      dispute_component = RiskScorer::DisputeRateScorer.call(market).to_f * DISPUTE_RATE_MULTIPLIER
      similar_component = similar_result[:score].to_f * SIMILAR_OUTCOMES_MULTIPLIER
      ((type_base * 0.6) + (dispute_component * 0.25) + (similar_component * 0.15)).round.clamp(0, 100)
    rescue StandardError => e
      Rails.logger.error("[RiskScorer] historical_accuracy_score failed: #{e.class}: #{e.message}")
      type_base
    end

    def manipulation_risk_score(market, market_type, source_result)
      base = case market_type
      when "CRYPTO_PRICE" then 25
      when "SPORTS_OUTCOME" then 25
      when "ELECTION_POLITICAL" then 60
      when "MACRO_ECONOMIC" then 55
      when "GEOPOLITICAL" then 75
      else 70
      end

      vol = market.respond_to?(:volume) ? market.volume.to_f : 0.0
      base += 15 if vol > 0 && vol < THIN_MARKET_VOLUME_THRESHOLD

      base += 10 if source_result[:apply_source_floor]
      base.clamp(0, 100)
    rescue StandardError => e
      Rails.logger.error("[RiskScorer] manipulation_risk_score failed: #{e.class}: #{e.message}")
      base.clamp(0, 100)
    end

    def information_asymmetry_score(market, market_type, source_result)
      base = case market_type
      when "CRYPTO_PRICE" then 20
      when "SPORTS_OUTCOME" then 25
      when "ELECTION_POLITICAL" then 55
      when "MACRO_ECONOMIC" then 60
      when "GEOPOLITICAL" then 70
      else 65
      end

      source_signal = (source_result[:score].to_f / 20.0) * 40

      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s : ""
      insider_penalty = text.match?(/\binsider|private source|unpublished|anonymous source\b/i) ? 15 : 0

      ((base * 0.40) + (source_signal * 0.45) + insider_penalty).round.clamp(0, 100)
    end

    def confidence_tier_for(score, data_availability)
      base_tier = if score <= 35
        :high
      elsif score <= 65
        :medium
      else
        :low
      end

      missing_sources = []
      missing_sources << "AI refinement" unless data_availability[:llm_available]
      missing_sources << "similar markets analysis" unless data_availability[:embeddings_available]
      missing_sources << "resolution criteria" if data_availability[:resolution_criteria].to_s.strip.empty?

      degraded = case missing_sources.length
      when 0 then base_tier
      when 1 then degrade_once(base_tier)
      else :low
      end

      note = missing_sources.any? ? "Confidence reduced: #{missing_sources.join(', ')} unavailable." : nil
      if data_availability[:market_type_confidence].to_s.upcase == "LOW"
        low_conf_note = "Market type was difficult to classify - risk score leans more heavily on resolution criteria text analysis."
        note = [note, low_conf_note].compact.join(" ")
      end

      {
        tier: degraded,
        missing_sources: missing_sources,
        note: note.presence
      }
    end

    def type_base_weight_for(market_type_confidence)
      case market_type_confidence.to_s.upcase
      when "HIGH" then 0.50
      when "MEDIUM" then 0.40
      when "LOW" then 0.25
      else 0.40
      end
    end

    def degrade_once(tier)
      { high: :medium, medium: :low, low: :low }.fetch(tier, :low)
    end

    def apply_override_gates(total, breakdown, market)
      gates = RiskScoringConfig.override_gates
      manipulated_threshold = gates[:manipulation_floor_threshold].to_i
      manipulated_floor = gates[:manipulation_floor].to_i
      missing_criteria_floor = gates[:missing_criteria_floor].to_i

      if breakdown[:manipulation_risk][:score].to_i >= manipulated_threshold && known_manipulated_source?(market)
        return { score: [total, manipulated_floor].max, applied: "manipulation_floor" }
      end

      if market.respond_to?(:resolution_criteria) && market.resolution_criteria.to_s.strip.empty?
        return { score: [total, missing_criteria_floor].max, applied: "missing_criteria_floor" }
      end

      { score: total, applied: nil }
    end

    def known_manipulated_source?(market)
      text = market.respond_to?(:resolution_criteria) ? market.resolution_criteria.to_s : ""
      return false if text.strip.empty?

      RiskScoringConfig.known_manipulated_sources.any? do |source|
        text.match?(/\b#{Regexp.escape(source)}\b/i)
      end
    end

    def resolve_market_type(market, llm_result)
      llm_result ||= {}
      llm_market_type = llm_result[:market_type].to_s.upcase.presence
      confidence = llm_result[:market_type_confidence].to_s.upcase.presence
      reasoning = llm_result[:market_type_reasoning].to_s.presence

      if llm_market_type.present?
        log_market_type_source(market, :llm, reasoning)
        return {
          market_type: llm_market_type,
          source: :llm,
          confidence: confidence || "MEDIUM",
          reasoning: reasoning
        }
      end

      fallback_type = yaml_category_lookup(market.respond_to?(:category) ? market.category : nil)
      log_market_type_source(market, :yaml_fallback, market.respond_to?(:category) ? market.category : nil)
      {
        market_type: fallback_type,
        source: :yaml_fallback,
        confidence: "LOW",
        reasoning: "Fallback category mapping used because LLM market_type was unavailable."
      }
    end

    def yaml_category_lookup(category)
      RiskScoringConfig.market_type_lookup(category)[:market_type]
    end

    def log_market_type_source(market, source, detail)
      if source == :yaml_fallback
        Rails.logger.warn(
          "[RiskScorer] market_type falling back to YAML category lookup for '#{market.respond_to?(:event_question) ? market.event_question : "Unknown market"}' (category: '#{market.respond_to?(:category) ? market.category : ""}'). LLM unavailable."
        )
      else
        Rails.logger.info("[RiskScorer] market_type inferred from LLM for market '#{market.respond_to?(:event_question) ? market.event_question : "Unknown market"}'#{detail.present? ? ": #{detail}" : ""}")
      end
    end

    def persist_risk_score!(market, result)
      record = RiskScore.find_or_initialize_by(market: market)
      legacy_assignments = FACTOR_NAME_MAP.each_with_object({}) do |(factor_key, column_name), h|
        next unless record.has_attribute?(column_name)
        value = if factor_key == :liquidity
          result[:liquidity_risk]
        else
          result.dig(:factors, factor_key)
        end
        h[column_name] = value.to_f.round
      end

      record.assign_attributes(
        score: result[:score],
        level: normalize_level_for_record(result[:level]),
        computed_at: Time.current,
        confidence_tier: result[:confidence_tier],
        factors_imputed: result[:factors_imputed] || [],
        override_gate_applied: result[:override_gate_applied],
        factor_metadata: deep_stringify_keys(result[:factor_metadata] || {}),
        factors: deep_stringify_keys(result[:factors] || {}),
        **legacy_assignments
      )
      record.save!
    end

    def normalize_level_for_record(level)
      return "medium" if level == "moderate"
      return "high" if level == "very_high" || level == "critical"

      level
    end

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end
  end
end
