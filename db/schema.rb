# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_12_120001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "category_dispute_rates", force: :cascade do |t|
    t.string "category_slug", null: false
    t.integer "total_markets", default: 0, null: false
    t.integer "disputed_count", default: 0, null: false
    t.decimal "dispute_rate_pct", precision: 8, scale: 4
    t.datetime "last_updated_at"
    t.datetime "data_window_start"
    t.datetime "data_window_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_slug"], name: "index_category_dispute_rates_on_category_slug", unique: true
  end

  create_table "clarifications", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.text "previous_text", null: false
    t.text "new_text", null: false
    t.text "diff_html"
    t.datetime "detected_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_id"], name: "index_clarifications_on_market_id"
  end

  create_table "disputes", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.string "question_id", null: false
    t.string "proposed_outcome"
    t.string "final_outcome"
    t.integer "total_votes_for", default: 0
    t.integer "total_votes_against", default: 0
    t.integer "voter_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_id"], name: "index_disputes_on_market_id"
    t.index ["question_id"], name: "index_disputes_on_question_id"
  end

  create_table "llm_score_caches", force: :cascade do |t|
    t.string "cache_key", null: false
    t.string "model_id", null: false
    t.string "prompt_version", null: false
    t.jsonb "result_json", default: {}, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cache_key"], name: "index_llm_score_caches_on_cache_key", unique: true
    t.index ["expires_at"], name: "index_llm_score_caches_on_expires_at"
  end

  create_table "market_description_snapshots", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.text "description_text", null: false
    t.string "description_hash", null: false
    t.datetime "snapshot_at", null: false
    t.string "detected_change_type"
    t.decimal "edit_distance_ratio", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_id", "snapshot_at"], name: "idx_on_market_id_snapshot_at_3d62556077"
    t.index ["market_id"], name: "index_market_description_snapshots_on_market_id"
  end

# Could not dump table "market_embeddings" because of following StandardError
#   Unknown type 'vector(3072)' for column 'embedding_vector'


  create_table "markets", force: :cascade do |t|
    t.string "polymarket_id"
    t.text "resolution_criteria"
    t.string "category"
    t.datetime "end_date"
    t.string "status"
    t.decimal "volume"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_id"
    t.string "event_question"
    t.string "event_image"
    t.string "condition_id"
    t.index ["condition_id"], name: "index_markets_on_condition_id"
    t.index ["event_id"], name: "index_markets_on_event_id", unique: true
  end

  create_table "risk_scores", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.integer "score", null: false
    t.string "level", null: false
    t.jsonb "factors", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "computed_at"
    t.string "confidence_tier"
    t.integer "f1_ambiguity"
    t.integer "f2_source_dep"
    t.integer "f3_dispute_rate"
    t.integer "f4_time_spec"
    t.integer "f5_liquidity"
    t.integer "f6_historical_accuracy"
    t.string "factors_imputed", default: [], array: true
    t.string "override_gate_applied"
    t.jsonb "factor_metadata", default: {}
    t.index ["market_id"], name: "index_risk_scores_on_market_id"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "dispute_id", null: false
    t.bigint "wallet_id", null: false
    t.string "vote_direction", null: false
    t.decimal "token_amount", precision: 20, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispute_id"], name: "index_votes_on_dispute_id"
    t.index ["wallet_id"], name: "index_votes_on_wallet_id"
  end

  create_table "wallets", force: :cascade do |t|
    t.string "address", null: false
    t.integer "total_votes", default: 0
    t.decimal "accuracy_rate", precision: 5, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_wallets_on_address", unique: true
  end

  add_foreign_key "clarifications", "markets"
  add_foreign_key "disputes", "markets"
  add_foreign_key "market_description_snapshots", "markets"
  add_foreign_key "market_embeddings", "markets"
end
