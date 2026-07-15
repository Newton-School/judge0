require 'redis'

# Redis fixed-window per-minute limiter, global across pods; raises on Redis error.
class SubmissionRateLimiter
  def initialize(host:, port:, password:, clock: -> { Time.now.to_i })
    @redis = Redis.new(host: host, port: port, password: password)
    @clock = clock
  end

  # true if the key is within the given one-minute budget; raises on Redis error.
  def allow?(key, limit, amount = 1)
    window = @clock.call / 60
    redis_key = "judge0:rl:#{key}:#{window}"
    count = amount == 1 ? @redis.incr(redis_key) : @redis.incrby(redis_key, amount)
    @redis.expire(redis_key, 70) if count == amount
    count <= limit.to_i
  end
end
