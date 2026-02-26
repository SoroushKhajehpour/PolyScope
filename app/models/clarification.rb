# frozen_string_literal: true

class Clarification < ApplicationRecord
  belongs_to :market

  validates :previous_text, presence: true
  validates :new_text, presence: true
  validates :detected_at, presence: true
end
