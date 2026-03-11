# frozen_string_literal: true

class CreateMarketEmbeddings < ActiveRecord::Migration[8.0]
  def up
    create_table :market_embeddings, if_not_exists: true do |t|
      t.references :market, null: false, foreign_key: true
      t.string :embedding_model, null: false
      t.string :embedded_text_hash, null: false

      t.timestamps
    end

    add_index :market_embeddings, :embedded_text_hash, if_not_exists: true

    # pgvector: add vector column via SQL (extension enabled in 20260306100003_enable_pgvector)
    execute "ALTER TABLE market_embeddings ADD COLUMN embedding_vector vector(3072);" unless column_exists?(:market_embeddings, :embedding_vector)
  end

  def down
    execute "ALTER TABLE market_embeddings DROP COLUMN IF EXISTS embedding_vector;"
    drop_table :market_embeddings
  end
end
