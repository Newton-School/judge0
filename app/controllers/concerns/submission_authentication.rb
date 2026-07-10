require 'active_support/security_utils'

# Submission auth + per-user rate limit (NS-13252): service secret bypasses the
# limit, other tokens validate against newton-api. Auth fails closed; limiting fails open.
module SubmissionAuthentication
  extend ActiveSupport::Concern

  # Process-wide singletons so the cache/Redis persist across requests (controller is per-request).
  SINGLETON_MUTEX = Mutex.new

  class << self
    def token_validator
      @token_validator || SINGLETON_MUTEX.synchronize do
        @token_validator ||= CachingTokenValidator.new(
          NewtonTokenValidator.new(Rails.application.secrets.judge0_auth_validate_url),
          ttl_seconds: Rails.application.secrets.auth_cache_ttl_seconds.to_i,
          negative_ttl_seconds: 5,
          max_entries: Rails.application.secrets.auth_cache_max_entries.to_i
        )
      end
    end

    def rate_limiter
      @rate_limiter || SINGLETON_MUTEX.synchronize do
        @rate_limiter ||= SubmissionRateLimiter.new(
          Rails.application.secrets.rate_limit_redis_url,
          Rails.application.secrets.submission_rate_limit_per_minute
        )
      end
    end
  end

  private

  def authenticate_submission_request
    token = bearer_token
    return render_auth_error(401, "Unauthorized") if token.nil? || token.empty?

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
    @current_user_id = validation_result
  end

  def enforce_submission_rate_limit
    return if @is_service_caller
    return if @current_user_id.nil?

    begin
      unless SubmissionAuthentication.rate_limiter.allow?(@current_user_id)
        render json: { error: "Rate limit exceeded" }, status: 429
      end
    rescue StandardError
      # Fail open: a Redis blip (or limiter build failure) must not block submissions.
    end
  end

  def bearer_token
    auth_header = request.headers["Authorization"].to_s.strip
    return nil unless auth_header.downcase.start_with?("bearer ")
    auth_header[7..-1].to_s.strip
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
