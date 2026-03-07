# frozen_string_literal: true

class MarketEmbedding < ApplicationRecord
  belongs_to :market

  validates :embedding_model, presence: true
  validates :embedded_text_hash, presence: true
end
