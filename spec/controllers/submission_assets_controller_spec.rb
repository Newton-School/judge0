require 'rails_helper'

RSpec.describe SubmissionAssetsController, type: :controller do
  let(:submission) { create(:submission) }

  before do
    allow(Rails.application.secrets).to receive(:submission_service_token).and_return('svc-secret')
    request.headers['Authorization'] = 'Bearer svc-secret'
    submission.submission_assets.create!(logical_name: 'mars-state.txt', data: 'c3RhdGU=', size_bytes: 5)
    submission.submission_assets.create!(logical_name: 'mars-text.txt', data: 'dGV4dA==', size_bytes: 4)
  end

  it 'returns both requested assets in one response' do
    get :index, params: { submission_token: submission.token, file: 'mars-state.txt,mars-text.txt' }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['data']).to eq(
      'mars-state.txt' => 'c3RhdGU=',
      'mars-text.txt' => 'dGV4dA=='
    )
  end

  it 'returns available assets when an optional requested asset is absent' do
    get :index, params: { submission_token: submission.token, file: 'mars-state.txt,older-run.txt' }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['data']).to eq('mars-state.txt' => 'c3RhdGU=')
  end

  it 'rejects an empty or repeated file list' do
    get :index, params: { submission_token: submission.token, file: 'mars-state.txt,' }
    expect(response).to have_http_status(:bad_request)

    get :index, params: { submission_token: submission.token, file: 'mars-state.txt,mars-state.txt' }
    expect(response).to have_http_status(:bad_request)
  end

  it 'keeps the single-asset endpoint available' do
    get :show, params: { submission_token: submission.token, logical_name: 'mars-state.txt' }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq('data' => 'c3RhdGU=')
  end
end
