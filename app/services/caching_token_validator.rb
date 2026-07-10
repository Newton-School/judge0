# In-memory TTL cache: positive/negative results cached (never transient), bounded, thread-safe.
class CachingTokenValidator
  MAX_ENTRIES = 50_000

  def initialize(inner, ttl_seconds:, negative_ttl_seconds:,
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @inner = inner
    @ttl = ttl_seconds.to_i
    @negative_ttl = negative_ttl_seconds.to_i
    @clock = clock
    @entries = {}
    @mutex = Mutex.new
  end

  # Returns a user id String or :invalid; raises on transient (not cached).
  def validate(token)
    now = @clock.call
    @mutex.synchronize do
      entry = @entries[token]
      return entry[:value] if entry && now < entry[:expires_at]
    end

    value = @inner.validate(token) # may raise TransientError — intentionally not cached

    ttl = value == :invalid ? @negative_ttl : @ttl
    @mutex.synchronize do
      purge_expired(now) if @entries.size >= MAX_ENTRIES
      @entries[token] = { value: value, expires_at: now + ttl } if @entries.size < MAX_ENTRIES
    end
    value
  end

  private

  def purge_expired(now)
    @entries.delete_if { |_token, entry| now >= entry[:expires_at] }
  end
end
