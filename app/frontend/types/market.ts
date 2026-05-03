export interface MarketSearchResult {
  event_id: string
  event_question: string
  category: string | null
  event_image: string | null
  volume: number | null
  end_date: string | null
}

export interface MarketProps {
  id: number
  event_id: string
  event_question: string
  category: string | null
  event_image: string | null
  volume: number | null
  end_date: string | null
  resolution_criteria: string | null
}

export interface Factor {
  label: string
  score: number
  explanation: string | null
}

export interface ResolutionCriteria {
  criteriaText: string | null
  hasAmbiguity: boolean
  ambiguityLevel: string | null
  misinterpretations: Array<{
    issue: string
    description: string
    affectedPhrase?: string
  }> | null
  overallNote: string | null
  sourceLabel: string | null
}

export interface LiquidityNote {
  label: string | null
  explanation: string | null
}

export type FreshnessState = "fresh" | "soft_stale" | "blocking_stale"

export interface CriteriaSnapshotEntry {
  type: "snapshot"
  id: string
  at: string | null
  summary: string
  change_type: string | null
  edit_distance_ratio: number | null
}

export interface CriteriaClarificationEntry {
  type: "clarification"
  id: string
  at: string | null
  summary: string
  diff_html: string | null
}

export type CriteriaTimelineEntry = CriteriaSnapshotEntry | CriteriaClarificationEntry

export interface ScoreContextProps {
  risk_score_computed_at: string | null
  freshness: FreshnessState | null
  stale_reason: string | null
  blocking_display_stale: boolean
  criteria_timeline: CriteriaTimelineEntry[]
}

export interface SimilarResolvedMarketProps {
  event_id: string | null
  event_question: string
  status: string | null
  end_date: string | null
  similarity: number | null
  dispute_hint: string | null
}

export interface RiskScoreProps {
  score: number
  level: string
  confidence_tier: string | null
  computed_at: string | null
  summary: string | null
  confidence_note: string | null
  confidence_explanation: string | null
  factors: Factor[]
  top_risk_drivers: string[]
  why_not_higher_risk: string[]
  resolution_criteria: ResolutionCriteria | null
  liquidity: LiquidityNote | null
  data_sources_unavailable: string[]
  similar_resolved_markets: SimilarResolvedMarketProps[]
}

export interface DigestMarketEntry {
  event_id: string
  missing: boolean
  last_snapshot_at?: string | null
  last_clarification_at?: string | null
  risk_score_computed_at?: string | null
  freshness?: FreshnessState | null
  stale_reason?: string | null
  blocking_display_stale?: boolean
  rules_changed_after_score?: boolean
  score_label_outdated?: boolean
}
