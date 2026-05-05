require "base64"

class SubmissionAssetsController < ApplicationController
  before_action :set_submission_and_asset, only: [:show]

  # GET /submissions/:submission_token/assets/:logical_name
  #
  # Default: returns { "data": "<base64>" } JSON straight from the column.
  # With Accept: application/octet-stream: decoded bytes as a download.
  #
  # Per docs/superpowers/specs/2026-05-05-submission-assets-design.md.
  def show
    if @asset.data.nil?
      head :not_found
      return
    end

    if request.headers["Accept"] == "application/octet-stream"
      filename = @asset.source_filename.presence || @asset.logical_name
      send_data(Base64.decode64(@asset.data),
                type: "application/octet-stream",
                disposition: "attachment",
                filename: filename)
    else
      render json: { data: @asset.data }
    end
  end

  private

  def set_submission_and_asset
    submission = Submission.find_by(token: params[:submission_token])
    return head :not_found if submission.nil?

    @asset = submission.submission_assets.find_by(logical_name: params[:logical_name])
    return head :not_found if @asset.nil?
  end
end
