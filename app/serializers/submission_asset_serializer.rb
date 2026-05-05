class SubmissionAssetSerializer < ActiveModel::Serializer
  # Metadata only — `data` is intentionally omitted.
  # The bytes are surfaced via the dedicated endpoint
  # GET /submissions/:submission_token/assets/:logical_name to keep
  # typical submission JSON small.
  attributes :logical_name, :source_filename, :size_bytes, :error, :error_detail
end
