# frozen_string_literal: true

# Single place for score freshness / stale rules shared by HTML props and digest JSON.
class MarketFreshness
  FRESH = "fresh"
  SOFT_STALE = "soft_stale"
  BLOCKING_STALE = "blocking_stale"

  # True when the persisted row is the post-crash provisional score (used by HTML freshness + score_result polling).
  def self.provisional_scoring_failure_for_risk_score?(risk_score)
    return false unless risk_score

    return true if risk_score.override_gate_applied.to_s == "error_fallback"

    metadata = risk_score.factor_metadata
    return false unless metadata.is_a?(Hash)

    return true if metadata["scoring_fallback"] == true || metadata[:scoring_fallback] == true

    resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
    return false unless resolution.is_a?(Hash)

    resolution["fallback_reason"].to_s == "scoring_error" || resolution[:fallback_reason].to_s == "scoring_error"
  end

  class << self
    def blocking_display_stale?(market)
      new(market).blocking_display_stale?
    end

    # True when we may skip invoking RiskScorer: non-provisional score newer than 4 hours and no
    # clarifications after that score. Combined with #score_fresh? for UI freshness in #summary.
    def scoring_cache_valid?(market)
      new(market).scoring_cache_valid?
    end

    def score_fresh?(market)
      new(market).score_fresh?
    end

    # @return [Hash] keys: risk_score_computed_at, freshness, stale_reason, blocking_display_stale
    def summary(market)
      new(market).summary
    end

    # @param max_items [Integer] combined cap after merge
    def criteria_timeline(market, max_items: 25, snapshot_limit: 15, clarification_limit: 15)
      return [] unless market.respond_to?(:persisted?) && market.persisted?

      snaps = market.market_description_snapshots.order(snapshot_at: :desc).limit(snapshot_limit).to_a
      clars = market.clarifications.order(Arel.sql("COALESCE(clarifications.detected_at, clarifications.created_at) DESC")).limit(clarification_limit).to_a

      entries = []
      snaps.each do |s|
        entries << snapshot_entry(s)
      end
      clars.each do |c|
        entries << clarification_entry(c)
      end

      entries.sort_by { |e| timeline_entry_timestamp(e) }.reverse.first(max_items)
    end

    private

    def timeline_entry_timestamp(entry)
      raw = entry[:at].presence || entry["at"].presence
      return Time.at(0).utc if raw.blank?

      Time.iso8601(raw)
    rescue ArgumentError, TypeError
      Time.at(0).utc
    end

    def snapshot_entry(s)
      text = s.description_text.to_s
      {
        type: "snapshot",
        id: "snapshot-#{s.id}",
        at: s.snapshot_at&.iso8601,
        summary: truncate_summary(text),
        full_text: text,
        change_type: s.detected_change_type,
        edit_distance_ratio: s.edit_distance_ratio&.to_f
      }
    end

    def clarification_entry(c)
      at_time = c.detected_at.presence || c.created_at
      diff = c.diff_html.to_s
      {
        type: "clarification",
        id: "clarification-#{c.id}",
        at: at_time&.iso8601,
        summary: truncate_summary(c.new_text.to_s),
        full_text: c.new_text.to_s,
        diff_html: truncate_html(diff)
      }
    end

    def truncate_summary(text, max: 200)
      t = text.to_s.strip
      return "" if t.blank?

      t.length <= max ? t : "#{t[0, max].strip}…"
    end

    def truncate_html(html, max: 8000)
      h = html.to_s
      return nil if h.blank?

      h.length <= max ? h : "#{h[0, max]}…"
    end
  end

  def initialize(market)
    @market = market
  end

  def blocking_display_stale?
    score = @market.risk_score
    return false unless score&.computed_at.present?

    if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
      return true
    end

    false
  end

  def scoring_cache_valid?
    score = @market.risk_score
    return false unless score&.computed_at.present?
    return false unless score.computed_at > 4.hours.ago
    return false if MarketFreshness.provisional_scoring_failure_for_risk_score?(score)
    return false if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?

    true
  end

  def score_fresh?
    score = @market.risk_score
    return false unless score&.computed_at.present?
    return false unless score.computed_at > 4.hours.ago
    return false if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
    return false if market_end_within_24h?

    return false if provisional_scoring_failure? && LlmClient.new.configured?

    true
  end

  def summary
    score = @market.risk_score
    computed_iso = score&.computed_at&.iso8601

    if score.blank? || score.computed_at.blank?
      return {
        risk_score_computed_at: computed_iso,
        freshness: nil,
        stale_reason: nil,
        blocking_display_stale: false
      }
    end

    blocking = blocking_display_stale?
    freshness = if blocking
      BLOCKING_STALE
    elsif scoring_cache_valid? || score_fresh?
      FRESH
    else
      SOFT_STALE
    end

    {
      risk_score_computed_at: computed_iso,
      freshness: freshness,
      stale_reason: stale_reason(blocking: blocking),
      blocking_display_stale: blocking
    }
  end

  private

  # True only when the market has a future end time in the next 24 hours (past dates are ignored).
  def market_end_within_24h?
    return false unless @market.end_date.present?

    ends = @market.end_date
    return false if ends <= Time.current

    ends <= 24.hours.from_now
  end

  def provisional_scoring_failure?
    MarketFreshness.provisional_scoring_failure_for_risk_score?(@market.risk_score)
  end

  def stale_reason(blocking:)
    score = @market.risk_score
    return nil unless score&.computed_at.present?

    if blocking
      if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
        return "Resolution text changed after this score was computed."
      end
    end

    return nil if scoring_cache_valid? || score_fresh?

    reasons = []
    if market_end_within_24h?
      reasons << "Market closes within 24 hours."
    end

    metadata = score.factor_metadata
    if metadata.is_a?(Hash)
      resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
      if resolution.is_a?(Hash) && (resolution["from_fallback"] == true || resolution[:from_fallback] == true) && !LlmClient.new.configured?
        reasons << "Analysis used a reduced-quality path."
      end
    end

    reasons.first
  end
end
