# frozen_string_literal: true

class ExtendRiskScoresForSixFactors < ActiveRecord::Migration[8.0]
  def change
    add_column :risk_scores, :computed_at, :datetime
    add_column :risk_scores, :confidence_tier, :string
    add_column :risk_scores, :f1_ambiguity, :integer
    add_column :risk_scores, :f2_source_dep, :integer
    add_column :risk_scores, :f3_dispute_rate, :integer
    add_column :risk_scores, :f4_time_spec, :integer
    add_column :risk_scores, :f5_clarifications, :integer
    add_column :risk_scores, :f6_similar_outcomes, :integer
    add_column :risk_scores, :factors_imputed, :string, array: true, default: []
    add_column :risk_scores, :override_gate_applied, :string
    add_column :risk_scores, :factor_metadata, :jsonb, default: {}
  end
end
