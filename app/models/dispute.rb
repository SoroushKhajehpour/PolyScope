# frozen_string_literal: true

class Dispute < ApplicationRecord
  belongs_to :market

  validates :question_id, presence: true
end
