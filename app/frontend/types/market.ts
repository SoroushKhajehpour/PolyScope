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

export interface RiskScoreProps {
  score: number
  level: string
  confidence_tier: string | null
  computed_at: string | null
  summary: string | null
  confidence_note: string | null
  factors: Factor[]
  top_risk_drivers: string[]
  why_not_higher_risk: string[]
  resolution_criteria: ResolutionCriteria | null
  liquidity: LiquidityNote | null
  data_sources_unavailable: string[]
}
