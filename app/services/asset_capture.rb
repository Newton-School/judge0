require "base64"

# Captures language-declared artifacts from the isolate sandbox box
# and persists them as SubmissionAsset rows.
#
# Invoked by IsolateJob after run_cmd completes, before
# `isolate --cleanup` wipes the box.
#
# Per docs/superpowers/specs/2026-05-05-submission-assets-design.md.
class AssetCapture
  def initialize(box_path:, submission:, declarations:)
    @box_path     = box_path
    @submission   = submission
    @declarations = Array(declarations)
  end

  def call
    @declarations.each { |d| capture_one(d) }
  end

  private

  def capture_one(decl)
    pattern = build_pattern(decl[:identification])
    return if pattern.nil? # invalid regex — skip silently (validator catches at boot)

    matched = first_matching_filename(pattern)
    return if matched.nil? # no match — no row written

    file_path     = File.join(@box_path, matched)
    raw_size      = File.size(file_path)
    effective_cap = compute_cap(decl[:max_size])

    if raw_size > effective_cap
      write_size_limit_row(decl, matched, raw_size, effective_cap)
    else
      write_data_row(decl, matched, file_path)
    end
  end

  def first_matching_filename(pattern)
    Dir.entries(@box_path)
       .select { |f| File.file?(File.join(@box_path, f)) && pattern.match?(f) }
       .sort
       .first
  end

  def build_pattern(identification)
    Regexp.new(identification.to_s)
  rescue RegexpError
    nil
  end

  def compute_cap(declared)
    ceiling = Config::MAX_MAX_ASSET_SIZE
    [declared || ceiling, ceiling].min
  end

  def write_size_limit_row(decl, matched, raw_size, effective_cap)
    @submission.submission_assets.create!(
      logical_name:    decl[:name],
      source_filename: matched,
      size_bytes:      raw_size,
      error:           "size_limit_exceeded",
      error_detail:    "#{raw_size} bytes exceeds #{effective_cap} byte cap"
    )
  end

  def write_data_row(decl, matched, file_path)
    bytes = File.binread(file_path)
    @submission.submission_assets.create!(
      logical_name:    decl[:name],
      source_filename: matched,
      size_bytes:      bytes.bytesize,
      data:            Base64.strict_encode64(bytes)
    )
  rescue SystemCallError => e
    @submission.submission_assets.create!(
      logical_name:    decl[:name],
      source_filename: matched,
      size_bytes:      0,
      error:           "read_error",
      error_detail:    e.message
    )
  end
end
