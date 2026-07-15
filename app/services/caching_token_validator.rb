require "digest"

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
    key = digest(token)
    @mutex.synchronize do
      entry = @positive[key] || @negative[key]
      return entry[:value] if entry && now < entry[:expires_at]
    end

    value = @inner_validator.validate(token) # may raise TransientError — intentionally not cached

    store(now, key, value)
    value
  end

  def cached?(token)
    now = @clock.call
    key = digest(token)
    @mutex.synchronize do
      entry = @positive[key] || @negative[key]
      !entry.nil? && now < entry[:expires_at]
    end
  end

  private

  def digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def store(now, key, value)
    if value == :invalid
      cache, ttl = @negative, @negative_ttl
    else
      cache, ttl = @positive, @ttl
    end

    @mutex.synchronize do
      @positive.delete(key)
      @negative.delete(key)
      evict_one_expired(now) if @positive.size + @negative.size >= @max_entries
      return if @positive.size + @negative.size >= @max_entries

      cache[key] = { value: value, expires_at: now + ttl }
    end
  end

  def evict_one_expired(now)
    [@positive, @negative].each do |cache|
      pair = cache.first
      next unless pair && now >= pair[1][:expires_at]

      cache.shift
      return
    end
  end
end
