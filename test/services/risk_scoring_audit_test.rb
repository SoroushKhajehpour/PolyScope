# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class RiskScoringAuditTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    ApiDiagnostics.reset!
  end

  test "group A crypto objective markets score low" do
    with_analysis_level("NONE") do
      assert_operator score_for("Will BTC exceed $150k before Jan 2026?", category: "Crypto"), :<, 30
      assert_operator score_for("Will ETH be above $5000 on Dec 31?", category: "Cryptocurrency"), :<, 30
      assert_operator score_for("Will total crypto market cap hit $5T?", category: "DeFi"), :<, 35
    end
  end

  test "group B sports markets score low to moderate" do
    with_analysis_level("LOW") do
      assert_operator score_for("Will the Chiefs win Super Bowl LX?", category: "NFL"), :<, 45
      assert_operator score_for("Will Djokovic win Wimbledon?", category: "Tennis"), :<, 45
    end
  end

  test "group C politics scores moderate" do
    with_analysis_level("MODERATE") do
      score = score_for("Will Democrats win the Senate majority?", category: "Elections")
      assert_operator score, :>=, 35
      assert_operator score, :<=, 65
    end
  end

  test "group D subjective and unmapped categories score high" do
    with_analysis_level("HIGH") do
      assert_operator score_for("Will AI be considered sentient by 2030?", category: "AI"), :>, 60
      assert_operator score_for("Will the response be deemed adequate?", category: ""), :>, 65
    end
  end

  test "unmapped category warning fires" do
    logger = Minitest::Mock.new
    logger.expect(:warn, nil, [String])
    market = Market.new(category: "", resolution_criteria: "Resolved by official source.")

    Rails.stub(:logger, logger) do
      RiskScorer::MarketTypeClassifier.call(market)
    end
    assert logger.verify
  end

  test "misinterpretation analyzer fallback without key still allows scoring" do
    market = build_market("Will BTC hit $100k?", "Crypto", "Resolved by official API closing price on 2026-12-31.")
    with_env("OPENAI_API_KEY" => nil) do
      result = RiskScorer.call(market, persist: false)
      analysis = result.dig(:factor_metadata, :resolution_analysis)
      assert analysis[:from_fallback]
      assert result[:score].present?
    end
  end

  test "liquidity removed from main weighted score and still returned as parallel signal" do
    refute_includes RiskScorer::FACTOR_WEIGHTS.keys, :liquidity
    assert_in_delta 1.0, RiskScorer::FACTOR_WEIGHTS.values.sum, 0.0001
    result = RiskScorer.call(build_market("Q?", "Crypto", "Resolved by official source"), persist: false)
    assert result[:liquidity_risk].between?(0, 100)
  end

  test "confidence degrades when embeddings unavailable" do
    market = build_market("Will BTC exceed $150k?", "Crypto", "Resolved by official source on 2026-12-31.")
    with_analysis_level("NONE") do
      RiskScorer::SimilarOutcomesScorer.stub(:call, { score: 0, available: false, factor_metadata: {} }) do
        result = RiskScorer.call(market, persist: false)
        assert_equal "medium", result[:confidence_tier]
        assert_includes result.dig(:factor_metadata, :confidence, :missing_sources), "similar markets analysis"
      end
    end
  end

  test "override gate floors score for known manipulated source" do
    market = build_market("Will X happen?", "Geopolitics", "Outcome resolved by wikipedia editor discretion.")
    with_analysis_level("HIGH") do
      result = RiskScorer.call(market, persist: false)
      assert_operator result[:score], :>=, 65
    end
  end

  test "openai misinterpretation call uses cache to prevent duplicate api calls" do
    market = build_market("Will BTC hit $100k?", "Crypto", "Resolved by official API closing price on 2026-12-31.")
    call_count = 0

    analyzer = RiskScorer::ResolutionMisinterpretationAnalyzer.singleton_class
    analyzer.stub(:chat_completion, ->(*_args, **_kwargs) {
      call_count += 1
      { "hasAmbiguity" => false, "ambiguityLevel" => "NONE", "misinterpretations" => [], "overallNote" => "clear" }
    }) do
      with_env("OPENAI_API_KEY" => "x-test") do
        RiskScorer::ResolutionMisinterpretationAnalyzer.call(market, session_key: "s1")
        RiskScorer::ResolutionMisinterpretationAnalyzer.call(market, session_key: "s1")
      end
    end

    assert_equal 1, call_count
  end

  test "fallback misinterpretation analysis does not flag explicit written dates as vague timing" do
    assert_no_vague_timing(
      "If Iran halts or severely restricts international maritime traffic through the " \
      "Strait of Hormuz by December 31, 2026, 11:59 PM ET, this market will resolve to 'Yes'."
    )
    assert_no_vague_timing(
      "This market will resolve to 'Yes' if The Second Coming of Jesus Christ occurs " \
      "by December 31, 2026, 11:59 PM ET."
    )

    assert_no_vague_timing("resolves by January 1, 2027")
    assert_no_vague_timing("resolves YES if X occurs by December 31, 2026, 11:59 PM ET.")
    assert_no_vague_timing("resolves by Jan 1, 2027")
    assert_no_vague_timing("resolves by 2026-12-31")
    assert_no_vague_timing("resolves by 31/12/2026")
    assert_no_vague_timing("resolves by end of 2026")
    assert_no_vague_timing("resolves before end of Q4 2026")
    assert_no_vague_timing("resolves by end of Q4 2026")
    assert_no_vague_timing("resolves by December 2026")
    assert_no_vague_timing("prior to Q1 2027")
    assert_no_vague_timing("must happen prior to Q4 2026")

    assert_vague_timing("resolves if X happens before the next election")
    assert_vague_timing("resolves after officials make a decision")
    assert_vague_timing("resolves by the time the ceasefire is announced")
    assert_vague_timing("must happen prior to the scheduled event")
    assert_vague_timing("resolves after the event concludes")
    assert_vague_timing("resolves by the time officials decide")
  end

  test "llm market type classification is preferred over yaml category fallback" do
    fake = {
      hasAmbiguity: false,
      ambiguityLevel: "NONE",
      misinterpretations: [],
      overallNote: "clear",
      from_fallback: false,
      market_type: "CRYPTO_PRICE",
      market_type_confidence: "HIGH",
      market_type_reasoning: "Title includes BTC and a concrete price threshold."
    }
    market = build_market("Will BTC hit $100k?", "General", "Resolves by official exchange close on 2026-12-31.")

    RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { fake }) do
      result = RiskScorer.call(market, persist: false)
      assert_equal :CRYPTO_PRICE, result[:market_type]
      assert_equal :llm, result[:market_type_source]
      assert_operator result[:resolution_clarity_base], :<=, 20
      assert_operator result[:total_score] || result[:score], :<, 35
    end
  end

  test "yaml fallback is used and warning is logged when llm market_type is unavailable" do
    fake = {
      hasAmbiguity: true,
      ambiguityLevel: "MODERATE",
      misinterpretations: [],
      overallNote: "fallback",
      from_fallback: true,
      market_type: nil,
      market_type_confidence: nil,
      market_type_reasoning: nil
    }
    market = build_market("Will BTC hit $100k?", "Crypto", "Resolves by official source on 2026-12-31.")
    logger = Minitest::Mock.new
    logger.expect(:warn, nil, [String])

    Rails.stub(:logger, logger) do
      RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { fake }) do
        result = RiskScorer.call(market, persist: false)
        assert_equal :yaml_fallback, result[:market_type_source]
      end
    end

    assert logger.verify
  end

  test "low-confidence market type reduces type base weight" do
    fake = {
      hasAmbiguity: true,
      ambiguityLevel: "MODERATE",
      misinterpretations: [],
      overallNote: "uncertain type",
      from_fallback: false,
      market_type: "MACRO_ECONOMIC",
      market_type_confidence: "LOW",
      market_type_reasoning: "Weak objective cues in title and criteria."
    }
    market = build_market("Will this index move?", "General", "Resolves by an unspecified report.")
    RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { fake }) do
      result = RiskScorer.call(market, persist: false)
      assert_equal 0.25, result[:type_base_weight]
    end
  end

  test "second coming market remains high risk without vague timing false positive" do
    fake = {
      hasAmbiguity: true,
      ambiguityLevel: "HIGH",
      misinterpretations: [
        { issue: "Subjective threshold", description: "Consensus language is discretionary.", affectedPhrase: "consensus of credible sources" }
      ],
      overallNote: "Subjective resolution source introduces high ambiguity.",
      from_fallback: false,
      market_type: "SUBJECTIVE_QUALITATIVE",
      market_type_confidence: "HIGH",
      market_type_reasoning: "Relies on consensus and judgment."
    }
    market = build_market(
      "Will the Second Coming of Jesus Christ occur by Dec 31 2026?",
      "General",
      "Resolves YES if The Second Coming occurs by December 31, 2026, 11:59 PM ET, based on consensus of credible sources."
    )
    RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { fake }) do
      result = RiskScorer.call(market, persist: false)
      assert_operator result[:score], :>, 70
      assert_equal :SUBJECTIVE_QUALITATIVE, result[:market_type]
      issues = Array(result.dig(:factor_metadata, :resolution_analysis, :misinterpretations)).map { |m| m[:issue].to_s }
      refute_includes issues, "Vague timing"
    end
  end

  private

  def score_for(question, category:)
    score_result_for(question, category: category)[:score]
  end

  def score_result_for(question, category: "General")
    with_analysis_level(default_analysis_level_for(question)) do
      RiskScorer.call(build_market(question, category, question), persist: false)
    end
  end

  def build_market(question, category, criteria)
    Market.new(
      event_question: question,
      category: category,
      resolution_criteria: criteria,
      end_date: 8.months.from_now,
      volume: 2_000_000
    )
  end

  def default_analysis_level_for(question)
    text = question.to_s.downcase
    return "HIGH" if text.include?("sentient") || text.include?("deemed")
    return "NONE" if text.include?("btc") || text.include?("eth") || text.include?("wimbledon")

    "MODERATE"
  end

  def with_analysis_level(level, &blk)
    fake = {
      hasAmbiguity: level != "NONE",
      ambiguityLevel: level,
      misinterpretations: [],
      overallNote: "stubbed",
      market_type: nil,
      market_type_confidence: nil,
      market_type_reasoning: nil,
      from_fallback: false
    }
    RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { fake }) do
      yield
    end
  end

  def with_env(vars)
    old = {}
    vars.each do |k, v|
      old[k] = ENV[k]
      v.nil? ? ENV.delete(k) : ENV[k] = v
    end
    yield
  ensure
    old.each do |k, v|
      v.nil? ? ENV.delete(k) : ENV[k] = v
    end
  end

  def assert_no_vague_timing(text)
    analysis = RiskScorer::ResolutionMisinterpretationAnalyzer.fallback_misinterpretation_analysis(text)
    issues = Array(analysis[:misinterpretations]).map { |m| m[:issue].to_s }
    refute_includes issues, "Vague timing"
  end

  def assert_vague_timing(text)
    analysis = RiskScorer::ResolutionMisinterpretationAnalyzer.fallback_misinterpretation_analysis(text)
    issues = Array(analysis[:misinterpretations]).map { |m| m[:issue].to_s }
    assert_includes issues, "Vague timing"
  end
end

class ApiRateLimitingAuditTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    ApiDiagnostics.reset!
    ActiveJob::Base.queue_adapter = :test
  end

  test "same market id within 60s makes one external call" do
    counter = { event: 0 }
    fake_client = Object.new
    fake_client.define_singleton_method(:event) do |event_id|
      counter[:event] += 1
      {
        "id" => event_id,
        "title" => "Will BTC exceed 100k?",
        "description" => "Resolved by exchange close data",
        "endDate" => 8.months.from_now.iso8601,
        "liquidity" => "100000",
        "volume" => "1000000",
        "active" => true
      }
    end
    fake_client.define_singleton_method(:search) { |_q| { "events" => [] } }

    PolymarketClient.stub(:new, fake_client) do
      get market_path("event-1")
      get market_path("event-1")
    end

    assert_equal 1, counter[:event]
  end

  test "rapid fire search requests are deduped by cache" do
    counter = { search: 0 }
    fake_client = Object.new
    fake_client.define_singleton_method(:event) { |_id| raise Faraday::Error, "not found" }
    fake_client.define_singleton_method(:search) do |_q|
      counter[:search] += 1
      {
        "events" => [{ "id" => "e1", "title" => "Will X happen?", "markets" => [] }]
      }
    end

    PolymarketClient.stub(:new, fake_client) do
      10.times { get live_search_markets_path(q: "btc") }
    end

    assert_operator counter[:search], :<=, 2
  end

  test "llm is never called on search, only on explicit market select" do
    call_counter = 0
    fake_client = Object.new
    fake_client.define_singleton_method(:search) { |_q| { "events" => [{ "id" => "event-1", "title" => "Will BTC rise?", "markets" => [] }] } }
    fake_client.define_singleton_method(:event) do |event_id|
      {
        "id" => event_id,
        "title" => "Will BTC rise?",
        "description" => "Resolved by official source on 2026-12-31.",
        "endDate" => 8.months.from_now.iso8601,
        "liquidity" => "100000",
        "volume" => "2000000",
        "active" => true
      }
    end

    PolymarketClient.stub(:new, fake_client) do
      RiskScorer::ResolutionMisinterpretationAnalyzer.stub(:call, ->(_market, session_key: nil) { call_counter += 1; { hasAmbiguity: false, ambiguityLevel: "NONE", misinterpretations: [], overallNote: "ok", from_fallback: false } }) do
        get live_search_markets_path(q: "bitcoin")
        assert_equal 0, call_counter

        get market_path("event-1")
        perform_enqueued_jobs
        assert_operator call_counter, :>=, 1
      end
    end
  end
end
