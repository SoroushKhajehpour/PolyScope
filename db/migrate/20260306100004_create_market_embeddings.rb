# frozen_string_literal: true

class CreateMarketEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :market_embeddings do |t|
      t.references :market, null: false, foreign_key: true
      t.vector :embedding_vector, limit: 3072, null: false
      t.string :embedding_model, null: false
      t.string :embedded_text_hash, null: false

      t.timestamps
    end

    add_index :market_embeddings, :embedded_text_hash
  end
end
