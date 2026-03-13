# frozen_string_literal: true

require "monitor"

module RiskScorer
  module AiCallGovernor
    SESSION_MAX_CALLS = 20
    SESSION_MAX_CALLS_PER_MINUTE = 3
    MAX_WAIT_SECONDS = 30

    @monitor = Monitor.new
    @pending = {}

    class << self
      def with_dedup_lock(key)
        return yield if key.blank?

        entry = nil
        owner = false
        @monitor.synchronize do
          if @pending.key?(key)
            entry = @pending[key]
          else
            @pending[key] = { status: :running, cond: @monitor.new_cond, result: nil }
            entry = @pending[key]
            owner = true
          end
        end

        unless owner
          @monitor.synchronize do
            entry[:cond].wait_while { entry[:status] == :running }
            return entry[:result]
          end
        end

        result = yield
        @monitor.synchronize do
          @pending[key][:result] = result
          @pending[key][:status] = :done
          @pending[key][:cond].broadcast
          @pending.delete(key)
        end
        result
      rescue StandardError
        @monitor.synchronize do
          if @pending[key]
            @pending[key][:status] = :done
            @pending[key][:result] = nil
            @pending[key][:cond].broadcast
            @pending.delete(key)
          end
        end
        raise
      end

      # @return [Hash] { allowed: Boolean, reason: String|nil }
      def acquire_budget(provider:, session_key:)
        skey = normalized_session_key(session_key)
        minute = Time.current.to_i / 60

        total_key = "ai_budget:#{provider}:#{skey}:total"
        minute_key = "ai_budget:#{provider}:#{skey}:minute:#{minute}"

        total = Rails.cache.read(total_key).to_i
        return { allowed: false, reason: "AI scoring limit reached for this session. Using estimated scores." } if total >= SESSION_MAX_CALLS

        waited = 0
        until Rails.cache.read(minute_key).to_i < SESSION_MAX_CALLS_PER_MINUTE
          waited += 1
          if waited > MAX_WAIT_SECONDS
            return { allowed: false, reason: "Rate limit wait exceeded. Using estimated scores." }
          end
          sleep 1
          minute = Time.current.to_i / 60
          minute_key = "ai_budget:#{provider}:#{skey}:minute:#{minute}"
        end

        Rails.cache.write(total_key, 0, expires_in: 24.hours) unless Rails.cache.read(total_key)
        Rails.cache.increment(total_key)
        Rails.cache.write(minute_key, 0, expires_in: 70.seconds) unless Rails.cache.read(minute_key)
        Rails.cache.increment(minute_key)

        { allowed: true, reason: nil }
      end

      private

      def normalized_session_key(session_key)
        raw = session_key.to_s.strip
        return "anonymous" if raw.blank?
        raw
      end
    end
  end
end
