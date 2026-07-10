require 'rails_helper'

RSpec.describe "Submission authentication", type: :request do
  let(:service_token) { "svc-secret" }

  before do
    allow(Rails.application.secrets).to receive(:submission_service_token).and_return(service_token)

    # Stub the process-wide singletons the concern uses, so no network / Redis
    # is hit and the real singletons are never built (RSpec tears these down
    # after each example → no cross-test leakage).
    @validator = instance_double(CachingTokenValidator)
    allow(@validator).to receive(:validate).with("user-tok").and_return("user-1")
    allow(@validator).to receive(:validate).with("bad-tok").and_return(:invalid)
    allow(SubmissionAuthentication).to receive(:token_validator).and_return(@validator)

    @limiter = instance_double(SubmissionRateLimiter)
    allow(@limiter).to receive(:allow?).and_return(true)
    allow(SubmissionAuthentication).to receive(:rate_limiter).and_return(@limiter)
  end

  describe "auth branch" do
    it "401 without a bearer" do
      get "/submissions/anytoken"
      expect(response.status).to eq(401)
    end

    it "403 with an invalid bearer" do
      get "/submissions/anytoken", headers: { "Authorization" => "Bearer bad-tok" }
      expect(response.status).to eq(403)
    end

    it "503 when the validator is transiently unavailable (fail closed)" do
      allow(@validator).to receive(:validate)
        .and_raise(NewtonTokenValidator::TransientError.new("down"))
      get "/submissions/anytoken", headers: { "Authorization" => "Bearer whatever" }
      expect(response.status).to eq(503)
    end

    it "allows the service token" do
      post "/submissions", params: attributes_for(:valid_submission),
                           headers: { "Authorization" => "Bearer #{service_token}" }
      expect(response.status).not_to eq(401)
      expect(response.status).not_to eq(403)
    end

    it "allows a valid user bearer" do
      post "/submissions", params: attributes_for(:valid_submission),
                           headers: { "Authorization" => "Bearer user-tok" }
      expect(response.status).not_to eq(401)
      expect(response.status).not_to eq(403)
    end
  end

  describe "rate limit" do
    it "429s a user over the per-minute limit" do
      allow(@limiter).to receive(:allow?).and_return(false)
      post "/submissions", params: attributes_for(:valid_submission),
                           headers: { "Authorization" => "Bearer user-tok" }
      expect(response.status).to eq(429)
    end

    it "does not rate-limit the service caller even when the limiter would block" do
      allow(@limiter).to receive(:allow?).and_return(false)
      post "/submissions", params: attributes_for(:valid_submission),
                           headers: { "Authorization" => "Bearer #{service_token}" }
      expect(response.status).not_to eq(429)
    end

    it "fails open when the limiter raises (Redis down)" do
      allow(@limiter).to receive(:allow?).and_raise(StandardError.new("redis down"))
      post "/submissions", params: attributes_for(:valid_submission),
                           headers: { "Authorization" => "Bearer user-tok" }
      expect(response.status).not_to eq(429)
    end
  end
end
