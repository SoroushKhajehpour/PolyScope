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

ActiveRecord::Schema[8.0].define(version: 2026_02_25_024200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "markets", force: :cascade do |t|
    t.string "polymarket_id"
    t.string "question"
    t.text "resolution_criteria"
    t.string "category"
    t.datetime "end_date"
    t.string "status"
    t.decimal "yes_price"
    t.decimal "no_price"
    t.decimal "volume"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "risk_scores", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.integer "score", null: false
    t.string "level", null: false
    t.jsonb "factors", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  add_foreign_key "risk_scores", "markets"
  add_foreign_key "votes", "disputes"
  add_foreign_key "votes", "wallets"
end
