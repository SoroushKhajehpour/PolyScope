# frozen_string_literal: true

class CreateLlmScoreCache < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_score_caches do |t|
      t.string :cache_key, null: false
      t.string :model_id, null: false
      t.string :prompt_version, null: false
      t.jsonb :result_json, null: false, default: {}
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :llm_score_caches, :cache_key, unique: true
    add_index :llm_score_caches, :expires_at
  end
end
