# frozen_string_literal: true

class ApiDiagnostics
  @mutex = Mutex.new
  @stats = {
    total_calls: 0,
    cache_hits: 0,
    deduped_calls: 0,
    throttled_calls: 0,
    by_service: {},
    rate_limits: {}
  }

  class << self
    def record_call(service:, cache_hit: false, deduped: false, throttled: false)
      @mutex.synchronize do
        @stats[:total_calls] += 1
        @stats[:cache_hits] += 1 if cache_hit
        @stats[:deduped_calls] += 1 if deduped
        @stats[:throttled_calls] += 1 if throttled
        @stats[:by_service][service] ||= { calls: 0, cache_hits: 0 }
        @stats[:by_service][service][:calls] += 1
        @stats[:by_service][service][:cache_hits] += 1 if cache_hit
      end
    end

    def record_rate_limit(service:, headers:)
      limit = headers["x-ratelimit-limit"] || headers["X-RateLimit-Limit"]
      remaining = headers["x-ratelimit-remaining"] || headers["X-RateLimit-Remaining"]
      retry_after = headers["retry-after"] || headers["Retry-After"]
      return if limit.nil? && remaining.nil? && retry_after.nil?

      limit_i = limit.to_i
      remaining_i = remaining.to_i
      usage_pct = if limit_i.positive?
        (((limit_i - remaining_i).to_f / limit_i.to_f) * 100.0).round(1)
      else
        nil
      end

      if usage_pct && usage_pct >= 80.0
        Rails.logger.warn("[ApiDiagnostics] #{service} approaching rate limit: #{usage_pct}% used")
      end

      @mutex.synchronize do
        @stats[:rate_limits][service] = {
          limit: limit_i.zero? ? nil : limit_i,
          remaining: remaining_i.zero? ? nil : remaining_i,
          retry_after: retry_after&.to_s,
          usage_pct: usage_pct
        }
      end
    end

    def snapshot
      @mutex.synchronize do
        total = @stats[:total_calls]
        cache_hit_rate = total.positive? ? ((@stats[:cache_hits].to_f / total.to_f) * 100.0).round(1) : 0.0
        base = @stats.merge(cache_hit_rate: cache_hit_rate)
        base[:openai] = section_for_prefix("openai")
        base[:anthropic] = section_for_prefix("anthropic")
        base
      end
    end

    def reset!
      @mutex.synchronize do
        @stats = {
          total_calls: 0,
          cache_hits: 0,
          deduped_calls: 0,
          throttled_calls: 0,
          by_service: {},
          rate_limits: {}
        }
      end
    end

    private

    def section_for_prefix(prefix)
      by_service = @stats[:by_service] || {}
      rate_limits = @stats[:rate_limits] || {}
      keys = by_service.keys.select { |k| k.to_s.start_with?("#{prefix}.") }
      calls = keys.sum { |k| (by_service[k][:calls] || 0).to_i }
      cache_hits = keys.sum { |k| (by_service[k][:cache_hits] || 0).to_i }
      rl_keys = rate_limits.keys.select { |k| k.to_s.start_with?("#{prefix}.") }
      provider_rl = rl_keys.map { |k| rate_limits[k] }.first
      {
        calls: calls,
        cache_hits: cache_hits,
        cache_hit_rate: calls.positive? ? ((cache_hits.to_f / calls) * 100.0).round(1) : 0.0,
        rate_limit: provider_rl
      }
    end
  end
end
