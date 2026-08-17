require 'active_support/security_utils'
require 'ipaddr'

# Submission auth + rate limit (NS-13252): service secret bypasses; valid token -> per-user id,
# no token -> anonymous per-IP. Submissions and reads are limited per user (logged-in) or per IP
# (anonymous). A validation cache (positive + negative TTL) absorbs repeat lookups; uncached
# validations hit newton-api directly, with no separate per-request gate (matching judge-pyro) —
# an earlier per-IP gate collapsed a whole exam-centre NAT into one validation budget and 503'd
# the room. The limiter fails closed (limiter error -> 503).
module SubmissionAuthentication
  extend ActiveSupport::Concern

  # Process-wide singletons so the cache/Redis persist across requests (controller is per-request).
  SINGLETON_MUTEX = Mutex.new

  class << self
    def token_validator
      @token_validator || SINGLETON_MUTEX.synchronize do
        @token_validator ||= CachingTokenValidator.new(
          NewtonTokenValidator.new(Rails.application.secrets.judge0_auth_validate_url),
          ttl_seconds: Rails.application.secrets.auth_positive_cache_ttl_seconds.to_i,
          negative_ttl_seconds: Rails.application.secrets.auth_negative_cache_ttl_seconds.to_i,
          max_entries: Rails.application.secrets.auth_cache_max_entries.to_i
        )
      end
    end

    def rate_limiter
      @rate_limiter || SINGLETON_MUTEX.synchronize do
        @rate_limiter ||= SubmissionRateLimiter.new(
          host: ENV["REDIS_HOST"],
          port: ENV["REDIS_PORT"],
          password: ENV["REDIS_PASSWORD"]
        )
      end
    end
  end

  private

  def authenticate_submission_request
    token = bearer_token
    @client_ip = normalized_ip(client_ip)

    if token.nil? || token.empty?
      @is_service_caller = false
      @is_anonymous = true
      return
    end

    if service_token?(token)
      @is_service_caller = true
      return
    end

    validation_result =
      begin
        SubmissionAuthentication.token_validator.validate(token)
      rescue NewtonTokenValidator::TransientError
        return render_auth_error(503, "Auth temporarily unavailable")
      end

    return render_auth_error(403, "Invalid token") if validation_result == :invalid

    @is_service_caller = false
    @is_anonymous = false
    @current_user_id = validation_result
  end

  def enforce_submission_rate_limit
    return if @is_service_caller

    begin
      if @is_anonymous
        key = "ip:#{@client_ip}"
        limit = Rails.application.secrets.anon_submission_rate_limit_per_minute.to_i
      else
        return if @current_user_id.nil?
        key = "u:#{@current_user_id}"
        limit = Rails.application.secrets.submission_rate_limit_per_minute.to_i
      end
      unless SubmissionAuthentication.rate_limiter.allow?(key, limit, submission_cost)
        render json: { error: "Rate limit exceeded" }, status: 429
      end
    rescue StandardError
      # Fail closed: a limiter/Redis failure returns a generic 503, not free passage.
      render json: { error: "Service temporarily unavailable" }, status: 503
    end
  end

  def enforce_read_rate_limit
    return if @is_service_caller

    begin
      if @is_anonymous
        key = "r:#{@client_ip}"
        # Anonymous reads share a per-IP bucket, so a NAT egress funnels many pollers through one
        # key; give it its own (more generous) limit than a single logged-in user's bucket.
        limit = Rails.application.secrets.anon_read_rate_limit_per_minute.to_i
      else
        return if @current_user_id.nil?
        key = "r:u:#{@current_user_id}"
        limit = Rails.application.secrets.read_rate_limit_per_minute.to_i
      end
      unless SubmissionAuthentication.rate_limiter.allow?(key, limit)
        render json: { error: "Rate limit exceeded" }, status: 429
      end
    rescue StandardError
      # Fail closed: a limiter/Redis failure returns a generic 503, not free passage.
      render json: { error: "Service temporarily unavailable" }, status: 503
    end
  end

  def bearer_token
    auth_header = request.headers["Authorization"].to_s.strip
    return nil unless auth_header.downcase.start_with?("bearer ")
    auth_header[7..-1].to_s.strip
  end

  def submission_cost
    size = params[:submissions].respond_to?(:size) ? params[:submissions].size : 1
    [[size, 1].max, Config::MAX_SUBMISSION_BATCH_SIZE].min
  end

  def client_ip
    forwarded = request.headers["X-Forwarded-For"].to_s.split(",").map(&:strip).reject(&:empty?)
    forwarded.last || request.remote_ip
  end

  # Group IPv6 by /64 (matches pyro's client_ip normalization); IPv4 stays exact.
  def normalized_ip(ip)
    addr = IPAddr.new(ip.to_s)
    addr = addr.native if addr.ipv4_mapped?
    addr.ipv6? ? "#{addr.mask(64)}/64" : addr.to_s
  rescue IPAddr::InvalidAddressError
    ip.to_s
  end

  def service_token?(token)
    service_secret = Rails.application.secrets.submission_service_token.to_s
    return false if service_secret.empty?
    ActiveSupport::SecurityUtils.secure_compare(token, service_secret)
  end

  def render_auth_error(status, message)
    render json: { error: message }, status: status
  end
end
