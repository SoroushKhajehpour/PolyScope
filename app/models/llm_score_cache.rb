# frozen_string_literal: true

class LlmScoreCache < ApplicationRecord
  self.table_name = "llm_score_caches"

  # The column "cache_key" shadows ActiveRecord::Base#cache_key.
  # Suppress the DangerousAttributeError; use record[:cache_key] for column access.
  def self.instance_method_already_implemented?(method_name)
    return true if method_name.start_with?("cache_key")
    super
  end

  validates :cache_key, presence: true, uniqueness: true
  validates :model_id, presence: true
  validates :prompt_version, presence: true
  validates :expires_at, presence: true
end
