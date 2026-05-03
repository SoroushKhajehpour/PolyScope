# frozen_string_literal: true

# Wrapper for Anthropic Messages API. API key from ENV only (never hardcoded).
# Set ANTHROPIC_API_KEY in .env (dev/test) or environment (production).
# Optional: ANTHROPIC_MODEL overrides the model id (defaults to DEFAULT_MODEL).
class LlmClient
  DEFAULT_MODEL = "claude-sonnet-4-20250514"
  DEFAULT_MAX_TOKENS = 1024

  def initialize(api_key: nil)
    @api_key = (api_key.presence || ENV["ANTHROPIC_API_KEY"]).to_s.strip.presence
  end

  def configured?
    @api_key.present?
  end

  def self.default_model_id
    ENV["ANTHROPIC_MODEL"].to_s.strip.presence || DEFAULT_MODEL
  end

  # @param system [String] System prompt
  # @param user [String] User message
  # @param temperature [Float] 0 for deterministic
  # @param model [String] Model id (ENV["ANTHROPIC_MODEL"] wins when set)
  # @return [Hash] Parsed JSON from response, or {} on error/missing key
  def chat(system:, user:, temperature: 0.0, model: nil)
    return {} unless configured?

    model_id = ENV["ANTHROPIC_MODEL"].to_s.strip.presence || model.presence || DEFAULT_MODEL

    if defined?(Rails) && Rails.logger
      Rails.logger.info("[LlmClient] Anthropic Messages#create model=#{model_id} max_tokens=#{DEFAULT_MAX_TOKENS}")
    end

    client = Anthropic::Client.new(api_key: @api_key)
    attempts = 0
    begin
      attempts += 1
      # Anthropic SDK uses system_ for the system prompt (Ruby reserved word)
      response = client.messages.create(
        model: model_id,
        max_tokens: DEFAULT_MAX_TOKENS,
        messages: [{ role: "user", content: user }],
        temperature: temperature,
        system_: system
      )
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed
      retry if attempts < 2
      raise
    end
    ApiDiagnostics.record_call(service: "anthropic.messages") if defined?(ApiDiagnostics)
    text = extract_content(response)
    parsed = parse_json_from_text(text)
    if parsed.empty? && text.to_s.strip.present? && defined?(Rails)
      Rails.logger.warn(
        "[LlmClient] Anthropic returned non-empty body but JSON parse produced no keys " \
        "(check model output / prompts). model=#{model_id} excerpt=#{text.to_s[0, 500].inspect}"
      )
    end
    parsed
  rescue StandardError => e
    if defined?(Rails)
      detail = anthropic_error_detail(e)
      Rails.logger.error(
        "[LlmClient] Anthropic Messages API failed — #{e.class}: #{e.message}#{detail}"
      )
      Rails.logger.debug { Array(e.backtrace).first(12).join("\n") }
    end
    {}
  end

  private

  def anthropic_error_detail(exception)
    return "" unless exception.respond_to?(:response) && exception.response

    body = exception.response[:body] || exception.response.body
    body = body.to_json if body.is_a?(Hash)
    " response=#{body.to_s.truncate(800)}"
  rescue StandardError
    ""
  end

  def extract_content(response)
    content = response.content
    return content.to_s unless content.is_a?(Array)
    content.map do |b|
      if b.respond_to?(:text)
        b.text.to_s
      elsif b.respond_to?(:[])
        begin
          b[:text].to_s
        rescue StandardError
          b.to_s
        end
      else
        b.to_s
      end
    end.join
  end

  def parse_json_from_text(text)
    # Extract JSON object from response (may be wrapped in markdown code block)
    stripped = text.to_s.strip
    return {} if stripped.empty?

    json_src = nil
    if (m = stripped.match(/\A```(?:json)?\s*(\{[\s\S]*\})\s*```\z/m))
      json_src = m[1]
    elsif (m = stripped.match(/\A```(?:json)?\s*(\[[\s\S]*\])\s*```\z/m))
      json_src = m[1]
    elsif (m = stripped.match(/(\{[\s\S]*\})/m))
      json_src = m[1]
    else
      json_src = stripped
    end

    parsed = JSON.parse(json_src)
    return stringify_keys(parsed) if parsed.is_a?(Hash)
    if parsed.is_a?(Array)
      if defined?(Rails)
        Rails.logger.warn("[LlmClient] Anthropic returned JSON array; expected a single object. Using {}.")
      end
      return {}
    end
    {}
  rescue JSON::ParserError => e
    if defined?(Rails)
      Rails.logger.warn("[LlmClient] JSON::ParserError: #{e.message} excerpt=#{stripped[0, 300].inspect}")
    end
    {}
  end

  def stringify_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
    when Array
      obj.map { |v| stringify_keys(v) }
    else
      obj
    end
  end
end
