# In-memory TTL cache: positive/negative results cached (never transient), bounded, thread-safe.
class CachingTokenValidator
  def initialize(inner_validator, ttl_seconds:, negative_ttl_seconds:, max_entries:,
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @inner_validator = inner_validator
    @ttl = ttl_seconds.to_i
    @negative_ttl = negative_ttl_seconds.to_i
    @max_entries = max_entries.to_i
    @clock = clock
    @positive = {}
    @negative = {}
    @mutex = Mutex.new
  end

  # Returns a user id String or :invalid; raises on transient (not cached).
  def validate(token)
    now = @clock.call
    @mutex.synchronize do
      entry = @positive[token] || @negative[token]
      return entry[:value] if entry && now < entry[:expires_at]
    end

    value = @inner_validator.validate(token) # may raise TransientError — intentionally not cached

    store(now, token, value)
    value
  end

  private

  def store(now, token, value)
    if value == :invalid
      cache, ttl = @negative, @negative_ttl
    else
      cache, ttl = @positive, @ttl
    end

    @mutex.synchronize do
      @positive.delete(token)
      @negative.delete(token)
      purge_expired(now)
      return if @positive.size + @negative.size >= @max_entries

      cache[token] = { value: value, expires_at: now + ttl }
    end
  end

  def purge_expired(now)
    [@positive, @negative].each do |cache|
      while (pair = cache.first)
        break if now < pair[1][:expires_at]

        cache.shift
      end
    end
  end
end
