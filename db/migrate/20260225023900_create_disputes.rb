class CreateDisputes < ActiveRecord::Migration[8.0]
  def change
    create_table :disputes do |t|
      t.references :market, null: false, foreign_key: true
      t.string :question_id, null: false
      t.string :proposed_outcome
      t.string :final_outcome
      t.integer :total_votes_for, default: 0
      t.integer :total_votes_against, default: 0
      t.integer :voter_count, default: 0

      t.timestamps
    end

    add_index :disputes, :question_id
  end
end
