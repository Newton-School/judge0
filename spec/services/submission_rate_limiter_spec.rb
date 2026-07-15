require 'rails_helper'

RSpec.describe SubmissionRateLimiter do
  let(:redis) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(redis)
    allow(redis).to receive(:expire)
  end

  it "allows a key under its limit" do
    allow(redis).to receive(:incr).and_return(1)
    limiter = described_class.new(host: "localhost", port: 6379, password: nil)
    expect(limiter.allow?("k", 3)).to eq(true)
  end

  it "blocks a key over its limit" do
    allow(redis).to receive(:incr).and_return(4)
    limiter = described_class.new(host: "localhost", port: 6379, password: nil)
    expect(limiter.allow?("k", 3)).to eq(false)
  end

  it "sets an expiry only on the first hit in a window" do
    allow(redis).to receive(:incr).and_return(1)
    expect(redis).to receive(:expire).with(a_string_matching(/\Ajudge0:rl:k:\d+\z/), 70)
    limiter = described_class.new(host: "localhost", port: 6379, password: nil)
    limiter.allow?("k", 3)
  end

  it "does not set an expiry on a later hit in the same window" do
    allow(redis).to receive(:incr).and_return(2)
    expect(redis).not_to receive(:expire)
    limiter = described_class.new(host: "localhost", port: 6379, password: nil)
    limiter.allow?("k", 3)
  end

  it "constructs its redis client from host, port, and password" do
    expect(Redis).to receive(:new).with(host: "example", port: 6379, password: "secret").and_return(redis)
    allow(redis).to receive(:incr).and_return(1)
    described_class.new(host: "example", port: 6379, password: "secret").allow?("k", 3)
  end

  it "uses the injectable clock to key the window" do
    allow(redis).to receive(:incr).with("judge0:rl:k:0").and_return(1)
    limiter = described_class.new(host: "localhost", port: 6379, password: nil, clock: -> { 0 })
    expect(limiter.allow?("k", 3)).to eq(true)
  end

  it "resets the count at the next window boundary" do
    t = 0
    counts = Hash.new(0)
    allow(redis).to receive(:incr) { |key| counts[key] += 1 }
    limiter = described_class.new(host: "localhost", port: 6379, password: nil, clock: -> { t })
    expect(limiter.allow?("k", 1)).to eq(true)
    expect(limiter.allow?("k", 1)).to eq(false)
    t += 60
    expect(limiter.allow?("k", 1)).to eq(true)
  end

  it "enforces the given per-call limit across five calls" do
    counts = Hash.new(0)
    allow(redis).to receive(:incr) { |key| counts[key] += 1 }
    limiter = described_class.new(host: "localhost", port: 6379, password: nil, clock: -> { 0 })
    results = 5.times.map { limiter.allow?("k", 3) }
    expect(results).to eq([true, true, true, false, false])
  end

  it "charges the given amount via incrby and blocks once the budget is exceeded" do
    counts = Hash.new(0)
    allow(redis).to receive(:incrby) { |key, amount| counts[key] += amount }
    limiter = described_class.new(host: "localhost", port: 6379, password: nil, clock: -> { 0 })
    expect(limiter.allow?("k", 10, 6)).to eq(true)   # 6 <= 10
    expect(limiter.allow?("k", 10, 6)).to eq(false)  # 12 > 10
  end

  it "sets an expiry on the first amounted hit in a window" do
    allow(redis).to receive(:incrby).and_return(6)
    expect(redis).to receive(:expire).with(a_string_matching(/\Ajudge0:rl:k:\d+\z/), 70)
    described_class.new(host: "localhost", port: 6379, password: nil).allow?("k", 10, 6)
  end
end
