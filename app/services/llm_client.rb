# frozen_string_literal: true

# Wrapper for Anthropic Messages API. API key from ENV only (never hardcoded).
# Set ANTHROPIC_API_KEY in .env (dev/test) or environment (production).
class LlmClient
  DEFAULT_MODEL = "claude-sonnet-4-20250514"
  DEFAULT_MAX_TOKENS = 1024

  def initialize(api_key: nil)
    @api_key = api_key.presence || ENV["ANTHROPIC_API_KEY"]
  end

  def configured?
    @api_key.present?
  end

  # @param system [String] System prompt
  # @param user [String] User message
  # @param temperature [Float] 0 for deterministic
  # @param model [String] Model id
  # @return [Hash] Parsed JSON from response, or {} on error/missing key
  def chat(system:, user:, temperature: 0.0, model: DEFAULT_MODEL)
    return {} unless configured?

    client = Anthropic::Client.new(api_key: @api_key)
    # Anthropic SDK uses system_ for the system prompt (Ruby reserved word)
    response = client.messages.create(
      model: model,
      max_tokens: DEFAULT_MAX_TOKENS,
      messages: [{ role: "user", content: user }],
      temperature: temperature,
      system_: system
    )
    text = extract_content(response)
    parse_json_from_text(text)
  rescue StandardError => e
    Rails.logger.warn("[LlmClient] #{e.class}: #{e.message}") if defined?(Rails)
    {}
  end

  private

  def extract_content(response)
    content = response.content
    return content.to_s unless content.is_a?(Array)
    content.map { |b| b["text"] || b[:text] }.join
  end

  def parse_json_from_text(text)
    # Extract JSON object or array from response (may be wrapped in markdown code block)
    stripped = text.strip
    if (m = stripped.match(/\A```(?:json)?\s*(\{[\s\S]*\}|\[[\s\S]*\])\s*```\z/m))
      return JSON.parse(m[1]).to_h
    end
    if (m = stripped.match(/(\{[\s\S]*\}|\[[\s\S]*\])/m))
      return JSON.parse(m[1]).to_h
    end
    JSON.parse(stripped).to_h
  rescue JSON::ParserError
    {}
  end
end
