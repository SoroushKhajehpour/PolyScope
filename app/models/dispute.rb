# frozen_string_literal: true

class Dispute < ApplicationRecord
  belongs_to :market
  has_many :votes

  validates :question_id, presence: true
end
