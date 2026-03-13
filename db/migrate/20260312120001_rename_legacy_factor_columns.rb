# frozen_string_literal: true

class RenameLegacyFactorColumns < ActiveRecord::Migration[8.0]
  def change
    rename_column :risk_scores, :f5_clarifications, :f5_liquidity
    rename_column :risk_scores, :f6_similar_outcomes, :f6_historical_accuracy
  end
end
