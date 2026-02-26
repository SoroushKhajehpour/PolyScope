# frozen_string_literal: true

class Wallet < ApplicationRecord
  has_many :votes

  validates :address, presence: true, uniqueness: true
end
