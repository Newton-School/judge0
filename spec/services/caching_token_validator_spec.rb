require 'rails_helper'

RSpec.describe CachingTokenValidator do
  # Counts inner calls so we can assert caching behaviour.
  class CountingValidator
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = 0
    end

    def validate(_token)
      @calls += 1
      @result.is_a?(Exception) ? (raise @result) : @result
    end
  end

  it "caches a positive result" do
    inner = CountingValidator.new("u1")
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1000)
    3.times { expect(cv.validate("t")).to eq("u1") }
    expect(inner.calls).to eq(1)
  end

  it "caches an :invalid result" do
    inner = CountingValidator.new(:invalid)
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1000)
    3.times { expect(cv.validate("t")).to eq(:invalid) }
    expect(inner.calls).to eq(1)
  end

  it "does not cache transient errors" do
    inner = CountingValidator.new(NewtonTokenValidator::TransientError.new("down"))
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1000)
    2.times { expect { cv.validate("t") }.to raise_error(NewtonTokenValidator::TransientError) }
    expect(inner.calls).to eq(2)
  end

  it "re-validates after ttl expiry" do
    inner = CountingValidator.new("u1")
    t = 1_000_000
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1000, clock: -> { t })
    cv.validate("t")
    t += 120
    cv.validate("t")
    expect(inner.calls).to eq(2)
  end

  it "keys the cache per token" do
    inner = CountingValidator.new("u1")
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1000)
    cv.validate("a")
    cv.validate("b")
    expect(inner.calls).to eq(2)
  end

  it "bounds the number of cached entries" do
    inner = CountingValidator.new("u1")
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1)
    cv.validate("a")
    cv.validate("b")
    cv.validate("b")
    expect(inner.calls).to eq(3)
  end

  it "purges an expired entry to admit a new one at capacity" do
    inner = CountingValidator.new("u1")
    t = 1_000_000
    cv = described_class.new(inner, ttl_seconds: 60, negative_ttl_seconds: 5, max_entries: 1, clock: -> { t })
    cv.validate("a")
    t += 120
    cv.validate("b")
    cv.validate("b")
    expect(inner.calls).to eq(2)
  end
end
