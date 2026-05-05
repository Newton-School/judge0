require "rails_helper"
require "tmpdir"
require "fileutils"
require "base64"

RSpec.describe AssetCapture do
  let(:submission) { create(:valid_submission) }

  around do |example|
    Dir.mktmpdir do |dir|
      @box = dir
      example.run
    end
  end

  def declaration(overrides = {})
    { name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }.merge(overrides)
  end

  it "writes no row when no file matches the regex" do
    File.write(File.join(@box, "main.v"), "module x; endmodule")
    described_class.new(box_path: @box, submission: submission, declarations: [declaration]).call
    expect(submission.submission_assets.count).to eq(0)
  end

  it "writes no row when declarations is empty" do
    File.write(File.join(@box, "wave.vcd"), "x")
    described_class.new(box_path: @box, submission: submission, declarations: []).call
    expect(submission.submission_assets.count).to eq(0)
  end

  it "stores base64 data and raw size when file is within cap" do
    raw = "$date\nFri\n$end\n" # 17 bytes
    File.write(File.join(@box, "wave.vcd"), raw)

    described_class.new(box_path: @box, submission: submission, declarations: [declaration]).call

    a = submission.submission_assets.first
    expect(a.logical_name).to eq("wave.vcd")
    expect(a.source_filename).to eq("wave.vcd")
    expect(a.size_bytes).to eq(raw.bytesize)
    expect(a.error).to be_nil
    expect(Base64.decode64(a.data)).to eq(raw)
  end

  it "writes an error row when file exceeds the per-asset cap" do
    raw = "x" * 30_000
    File.write(File.join(@box, "wave.vcd"), raw)

    described_class.new(box_path: @box, submission: submission, declarations: [declaration(max_size: 20480)]).call

    a = submission.submission_assets.first
    expect(a.data).to be_nil
    expect(a.size_bytes).to eq(30_000)
    expect(a.error).to eq("size_limit_exceeded")
    expect(a.error_detail).to include("30000").and include("20480")
  end

  it "clamps a language max_size that exceeds MAX_MAX_ASSET_SIZE" do
    raw = "x" * 30_000
    File.write(File.join(@box, "wave.vcd"), raw)

    stub_const("Config::MAX_MAX_ASSET_SIZE", 20480)
    described_class.new(box_path: @box, submission: submission, declarations: [declaration(max_size: 1_000_000)]).call

    a = submission.submission_assets.first
    expect(a.error).to eq("size_limit_exceeded")
    expect(a.error_detail).to include("20480") # ceiling, not 1_000_000
  end

  it "uses MAX_MAX_ASSET_SIZE when declaration omits max_size" do
    raw = "x" * 100
    File.write(File.join(@box, "wave.vcd"), raw)

    stub_const("Config::MAX_MAX_ASSET_SIZE", 20480)
    described_class.new(
      box_path: @box,
      submission: submission,
      declarations: [{ name: "wave.vcd", identification: '\.vcd$' }]
    ).call

    a = submission.submission_assets.first
    expect(a.error).to be_nil
    expect(a.size_bytes).to eq(100)
  end

  it "picks first match alphabetically when regex matches multiple files" do
    File.write(File.join(@box, "z.vcd"), "z")
    File.write(File.join(@box, "a.vcd"), "a")
    File.write(File.join(@box, "m.vcd"), "m")

    described_class.new(box_path: @box, submission: submission, declarations: [declaration]).call

    a = submission.submission_assets.first
    expect(a.source_filename).to eq("a.vcd")
    expect(Base64.decode64(a.data)).to eq("a")
  end

  it "skips an asset declaration with invalid regex without raising" do
    File.write(File.join(@box, "wave.vcd"), "x")

    described_class.new(
      box_path: @box,
      submission: submission,
      declarations: [{ name: "wave.vcd", identification: "[broken" }]
    ).call

    expect(submission.submission_assets.count).to eq(0)
  end

  it "ignores subdirectories when matching filenames" do
    Dir.mkdir(File.join(@box, "sub.vcd")) # directory whose name happens to match
    File.write(File.join(@box, "sub.vcd", "inner.vcd"), "inner")
    File.write(File.join(@box, "real.vcd"), "real")

    described_class.new(box_path: @box, submission: submission, declarations: [declaration]).call

    a = submission.submission_assets.first
    expect(a.source_filename).to eq("real.vcd")
  end
end
