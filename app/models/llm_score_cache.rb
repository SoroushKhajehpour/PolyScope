# frozen_string_literal: true

class LlmScoreCache < ApplicationRecord
  self.table_name = "llm_score_caches"

  validates :cache_key, presence: true, uniqueness: true
  validates :model_id, presence: true
  validates :prompt_version, presence: true
  validates :expires_at, presence: true
end
