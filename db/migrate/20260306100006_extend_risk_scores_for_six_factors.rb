# frozen_string_literal: true

class ExtendRiskScoresForSixFactors < ActiveRecord::Migration[8.0]
  def change
    add_column :risk_scores, :computed_at, :datetime unless column_exists?(:risk_scores, :computed_at)
    add_column :risk_scores, :confidence_tier, :string unless column_exists?(:risk_scores, :confidence_tier)
    add_column :risk_scores, :f1_ambiguity, :integer unless column_exists?(:risk_scores, :f1_ambiguity)
    add_column :risk_scores, :f2_source_dep, :integer unless column_exists?(:risk_scores, :f2_source_dep)
    add_column :risk_scores, :f3_dispute_rate, :integer unless column_exists?(:risk_scores, :f3_dispute_rate)
    add_column :risk_scores, :f4_time_spec, :integer unless column_exists?(:risk_scores, :f4_time_spec)
    add_column :risk_scores, :f5_clarifications, :integer unless column_exists?(:risk_scores, :f5_clarifications)
    add_column :risk_scores, :f6_similar_outcomes, :integer unless column_exists?(:risk_scores, :f6_similar_outcomes)
    add_column :risk_scores, :factors_imputed, :string, array: true, default: [] unless column_exists?(:risk_scores, :factors_imputed)
    add_column :risk_scores, :override_gate_applied, :string unless column_exists?(:risk_scores, :override_gate_applied)
    add_column :risk_scores, :factor_metadata, :jsonb, default: {} unless column_exists?(:risk_scores, :factor_metadata)
  end
end
