require 'rails_helper'

RSpec.describe SubmissionsController, type: :controller do

  let(:submission) { create(:submission) }

  # Submission endpoints now require a bearer; authenticate every example as the
  # trusted service caller so these pre-existing behaviour tests are unaffected.
  before do
    allow(Rails.application.secrets).to receive(:submission_service_token).and_return("svc-secret")
    request.headers["Authorization"] = "Bearer svc-secret"
  end

  describe "GET #show" do
    it "returns one submission" do
      get :show, params: { token: submission.token }
      json = JSON.parse(response.body)
      expect(response).to be_success
      expect(json).to have_serialized(submission).with(SubmissionSerializer)
    end

    it "returns 404" do
      expect {
        get :show, params: { token: submission.token + " give me 404" }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET #show caching" do
    let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

    before { allow(Rails).to receive(:cache).and_return(memory_store) }

    it "caches the serialized body under a per-field-set key" do
      get :show, params: { token: submission.token, fields: "status" }
      cached = memory_store.read(controller.send(:submission_cache_key, submission.token))

      expect(cached).to eq(response.body)
      expect(cached).not_to include("stdin")
    end

    it "keys entries per requested field set instead of overwriting one entry" do
      get :show, params: { token: submission.token, fields: "status" }
      status_key = controller.send(:submission_cache_key, submission.token)

      get :show, params: { token: submission.token, fields: "status,time" }
      status_time_key = controller.send(:submission_cache_key, submission.token)

      expect(status_key).not_to eq(status_time_key)
      expect(memory_store.read(status_key)).to be_present
      expect(memory_store.read(status_time_key)).to be_present
    end

    it "serves a repeated identical request from the cache without a DB lookup" do
      get :show, params: { token: submission.token }
      first_body = response.body

      expect(Submission).not_to receive(:find_by!)
      get :show, params: { token: submission.token }

      expect(response.body).to eq(first_body)
    end

  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new Submission" do
        expect {
          post :create, params: attributes_for(:valid_submission)
        }.to change(Submission, :count).by(1)
      end

      it "returns only id of new Submission" do
        post :create, params: attributes_for(:valid_submission)
        json = JSON.parse(response.body)
        expect(response).to be_success
        expect(json).to have_serialized(Submission.first).with(SubmissionSerializer, { fields: [:token] })
      end

      it "doesn't create new Submission because given Language doesn't exist" do
        attributes = attributes_for(:valid_submission)
        attributes[:language_id] = 142 # Language with id 142 doesn't exist
        post :create, params: attributes
        expect(response).to have_http_status(422)
      end
    end

    context "with invalid params" do
      it "doesn't create new Submission" do
        post :create, params: { submission: attributes_for(:invalid_submission) }
        expect(response).to have_http_status(422)
      end
    end
  end
end
