class SubmissionAsset < ApplicationRecord
  belongs_to :submission

  validates :logical_name, presence: true
  validates :size_bytes,   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Rows with a non-null `error` represent a capture attempt that
  # produced no usable bytes (e.g. exceeded MAX_MAX_ASSET_SIZE).
  scope :with_data, -> { where(error: nil).where.not(data: nil) }
end
