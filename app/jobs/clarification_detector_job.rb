# frozen_string_literal: true

# Scheduled every 2h. Runs description snapshot and clarification detection.
class ClarificationDetectorJob < ApplicationJob
  queue_as :default

  def perform
    DescriptionSnapshotJob.perform_now
  end
end
