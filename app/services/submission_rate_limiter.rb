require 'redis'

# Redis fixed-window per-minute limiter, global across pods; raises on Redis error (caller fails open).
class SubmissionRateLimiter
  def initialize(redis_url, clock: -> { Time.now.to_i })
    @redis = Redis.new(url: redis_url)
    @clock = clock
  end

  # true if the key is within the given one-minute budget; raises on Redis error (caller fails open).
  def allow?(key, limit)
    window = @clock.call / 60
    redis_key = "judge0:rl:#{key}:#{window}"
    count = @redis.incr(redis_key)
    @redis.expire(redis_key, 70) if count == 1
    count <= limit.to_i
  end
end
