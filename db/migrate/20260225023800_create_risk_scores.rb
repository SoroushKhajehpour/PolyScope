class CreateRiskScores < ActiveRecord::Migration[8.0]
  def change
    create_table :risk_scores do |t|
      t.references :market, null: false, foreign_key: true
      t.integer :score, null: false
      t.string :level, null: false
      t.jsonb :factors, default: {}

      t.timestamps
    end
  end
end
