require "active_support/cache/redis_cache_store"

# RedisCacheStore keeps entries written with a race_condition_ttl alive for a
# hardcoded 5.minutes past their logical expiry so stale entries can be served
# while one request recomputes. For 1-second submission entries that padding is
# ~99% dead weight and pinned multi-MB cached submissions long enough to OOM
# the redis sidecar (2026-08-18). Same semantics, configurable padding.
class NewtonRedisCacheStore < ActiveSupport::Cache::RedisCacheStore
  RACE_CONDITION_PADDING_SECONDS =
    (ENV["CACHE_RACE_CONDITION_PADDING_SECONDS"].presence || 1).to_f

  private

  def write_entry(key, entry, unless_exist: false, raw: false, expires_in: nil, race_condition_ttl: nil, **options)
    if race_condition_ttl && expires_in && expires_in > 0 && !raw
      expires_in += RACE_CONDITION_PADDING_SECONDS
      race_condition_ttl = nil # the parent would pad by its own 5.minutes
    end

    super(key, entry,
          unless_exist: unless_exist, raw: raw, expires_in: expires_in,
          race_condition_ttl: race_condition_ttl, **options)
  end
end
