# In-memory TTL cache: positive/negative results cached (never transient), bounded, thread-safe.
class CachingTokenValidator
  def initialize(inner_validator, ttl_seconds:, negative_ttl_seconds:, max_entries:,
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @inner_validator = inner_validator
    @ttl = ttl_seconds.to_i
    @negative_ttl = negative_ttl_seconds.to_i
    @max_entries = max_entries.to_i
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

    value = @inner_validator.validate(token) # may raise TransientError — intentionally not cached

    ttl = value == :invalid ? @negative_ttl : @ttl
    @mutex.synchronize do
      purge_expired(now) if @entries.size >= @max_entries
      @entries[token] = { value: value, expires_at: now + ttl } if @entries.size < @max_entries
    end
    value
  end

  private

  def purge_expired(now)
    @entries.delete_if { |_token, entry| now >= entry[:expires_at] }
  end
end
