# frozen_string_literal: true

# Single place for score freshness / stale rules shared by HTML props and digest JSON.
class MarketFreshness
  FRESH = "fresh"
  SOFT_STALE = "soft_stale"
  BLOCKING_STALE = "blocking_stale"

  class << self
    def blocking_display_stale?(market)
      new(market).blocking_display_stale?
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
      return Time.zone.at(0) if raw.blank?

      Time.iso8601(raw)
    rescue ArgumentError, TypeError
      Time.zone.at(0)
    end

    def snapshot_entry(s)
      text = s.description_text.to_s
      {
        type: "snapshot",
        id: "snapshot-#{s.id}",
        at: s.snapshot_at&.iso8601,
        summary: truncate_summary(text),
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

    metadata = score.factor_metadata
    if metadata.is_a?(Hash)
      resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
      if resolution.is_a?(Hash) && (resolution["from_fallback"] == true || resolution[:from_fallback] == true)
        return true if LlmClient.new.configured?
      end
    end

    false
  end

  def score_fresh?
    score = @market.risk_score
    return false unless score&.computed_at.present?
    return false unless score.computed_at > 4.hours.ago
    return false if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
    return false if @market.end_date.present? && @market.end_date <= 24.hours.from_now

    metadata = score.factor_metadata
    if metadata.is_a?(Hash)
      resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
      if resolution.is_a?(Hash) && (resolution["from_fallback"] == true || resolution[:from_fallback] == true)
        return false if LlmClient.new.configured?
      end
    end

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
    elsif score_fresh?
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

  def stale_reason(blocking:)
    score = @market.risk_score
    return nil unless score&.computed_at.present?

    if blocking
      if @market.clarifications.where("clarifications.created_at > ?", score.computed_at).exists?
        return "Resolution text changed after this score was computed."
      end

      metadata = score.factor_metadata
      if metadata.is_a?(Hash)
        resolution = metadata["resolution_analysis"] || metadata[:resolution_analysis]
        if resolution.is_a?(Hash) && (resolution["from_fallback"] == true || resolution[:from_fallback] == true) && LlmClient.new.configured?
          return "Full analysis did not run last time; refresh recommended."
        end
      end

      return "Score may not reflect current rules."
    end

    return nil if score_fresh?

    reasons = []
    if score.computed_at <= 4.hours.ago
      reasons << "Score is older than four hours."
    end
    if @market.end_date.present? && @market.end_date <= 24.hours.from_now
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
