require "rails_helper"
require_relative "../../../db/languages/asset_validator"

RSpec.describe AssetValidator do
  describe ".validate_language" do
    let(:lang) { { id: 9999, name: "Test Lang" } }

    it "passes when no :assets array is present" do
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes when :assets is an empty array" do
      lang[:assets] = []
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes for a well-formed asset" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes when :max_size is omitted" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$' }]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "errors when :name is missing" do
      lang[:assets] = [{ identification: '\.vcd$' }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("missing :name"))
    end

    it "errors when :name is empty string" do
      lang[:assets] = [{ name: "", identification: '\.vcd$' }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("missing :name"))
    end

    it "errors when :identification is missing" do
      lang[:assets] = [{ name: "wave.vcd" }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("missing :identification"))
    end

    it "errors when :identification is not a valid regex" do
      lang[:assets] = [{ name: "wave.vcd", identification: '[unclosed' }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not valid regex"))
    end

    it "errors when :max_size is negative" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: -1 }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("max_size must be positive Integer"))
    end

    it "errors when :max_size is zero" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: 0 }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("max_size must be positive Integer"))
    end

    it "errors when :max_size is a String" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: "20480" }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("max_size must be positive Integer"))
    end

    it "reports multiple errors per asset declaration" do
      lang[:assets] = [{ identification: '[broken', max_size: -1 }]
      errors = described_class.validate_language(lang)
      expect(errors.size).to eq(3) # missing name + invalid regex + bad max_size
    end

    it "reports errors for each asset in a multi-asset declaration" do
      lang[:assets] = [
        { name: "good.txt", identification: '\.txt$' },          # valid
        { name: "bad",      identification: '[unclosed' },       # invalid regex
      ]
      errors = described_class.validate_language(lang)
      expect(errors.size).to eq(1)
      expect(errors.first).to include("not valid regex")
    end
  end
end
