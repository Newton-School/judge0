require 'net/http'
require 'json'
require 'uri'

# Validates a Bearer token via the newton-api endpoint (Judge0 holds no secret of its own).
class NewtonTokenValidator
  class TransientError < StandardError; end

  def initialize(validate_url)
    @validate_url = validate_url
  end

  # Returns user id, :invalid (401/403), or raises TransientError (caller fails closed).
  def validate(token)
    uri = URI.parse(@validate_url)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 3
    ) { |http| http.request(request) }

    case response.code.to_i
    when 200
      user_id = JSON.parse(response.body)["user_id"]
      raise TransientError, "empty user_id" if user_id.nil? || user_id.to_s.empty?
      user_id.to_s
    when 401, 403
      :invalid
    else
      raise TransientError, "unexpected status #{response.code}"
    end
  rescue TransientError
    raise
  rescue StandardError => error
    # Any network/TLS/parse failure is transient → fail closed (503), never a 500.
    raise TransientError, error.message
  end
end
