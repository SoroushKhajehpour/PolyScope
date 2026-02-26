# frozen_string_literal: true

class Vote < ApplicationRecord
  belongs_to :dispute
  belongs_to :wallet

  validates :vote_direction, presence: true
end
