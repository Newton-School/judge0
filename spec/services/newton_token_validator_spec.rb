require 'rails_helper'

RSpec.describe NewtonTokenValidator do
  # Inject a fake HTTP responder so we test our status/body mapping, not the network.
  def validator_returning(status, body = "")
    resp = Struct.new(:code, :body).new(status.to_s, body)
    fake = double("http")
    allow(fake).to receive(:request).and_return(resp)
    allow(Net::HTTP).to receive(:start).and_yield(fake).and_return(resp)
    described_class.new("http://newton.test/validate/")
  end

  it "returns the user id on 200 with a user_id" do
    v = validator_returning(200, '{"user_id":"u42"}')
    expect(v.validate("good")).to eq("u42")
  end

  it "returns :invalid on 401" do
    v = validator_returning(401)
    expect(v.validate("bad")).to eq(:invalid)
  end

  it "returns :invalid on 403" do
    v = validator_returning(403)
    expect(v.validate("bad")).to eq(:invalid)
  end

  it "raises TransientError on 500" do
    v = validator_returning(500)
    expect { v.validate("x") }.to raise_error(NewtonTokenValidator::TransientError)
  end

  it "raises TransientError on 200 with an empty user_id (fail closed)" do
    v = validator_returning(200, '{"user_id":""}')
    expect { v.validate("x") }.to raise_error(NewtonTokenValidator::TransientError)
  end

  it "raises TransientError on unparseable body" do
    v = validator_returning(200, 'not-json')
    expect { v.validate("x") }.to raise_error(NewtonTokenValidator::TransientError)
  end
end
