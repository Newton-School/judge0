require 'rails_helper'
require 'newton_redis_cache_store'

RSpec.describe NewtonRedisCacheStore do
  let(:fake_redis) do
    Class.new do
      attr_reader :sets

      def initialize
        @sets = []
      end

      def set(key, value, modifiers = {}, **kw_modifiers)
        @sets << [key, modifiers.merge(kw_modifiers)]
        true
      end

      def get(key)
        nil
      end
    end.new
  end

  subject(:store) { described_class.new(redis: fake_redis) }

  it "pads the physical TTL by the configured padding instead of Rails' 5 minutes" do
    store.write("k", "v", expires_in: 1, race_condition_ttl: 0.1)

    expected = (1 + described_class::RACE_CONDITION_PADDING_SECONDS).to_i
    expect(fake_redis.sets.last[1][:ex]).to eq(expected)
    expect(fake_redis.sets.last[1][:ex]).to be < 5.minutes
  end

  it "leaves writes without race_condition_ttl unpadded" do
    store.write("k", "v", expires_in: 5)

    expect(fake_redis.sets.last[1][:ex]).to eq(5)
  end
end
