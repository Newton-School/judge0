require "rails_helper"
require_relative "../../../db/languages/env_validator"

RSpec.describe EnvValidator do
  describe ".validate_language" do
    let(:lang) { { id: 9999, name: "Test Lang" } }

    it "passes when no :env key is present" do
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes when :env is an empty array" do
      lang[:env] = []
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes for all-uppercase POSIX-style names" do
      lang[:env] = %w[DOTNET_NOLOGO DOTNET_CLI_TELEMETRY_OPTOUT]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes for mixed-case names (.NET canonical form)" do
      lang[:env] = %w[DOTNET_EnableWriteXorExecute]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes for names with leading underscore" do
      lang[:env] = %w[_DEBUG]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "errors when :env is not an Array" do
      lang[:env] = "DOTNET_NOLOGO"
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("must be an Array"))
    end

    it "errors when :env is a Hash" do
      lang[:env] = { "FOO" => "bar" }
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("must be an Array"))
    end

    it "errors when an entry is not a String" do
      lang[:env] = [123]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("must be a String"))
    end

    it "errors when an entry starts with a digit" do
      lang[:env] = %w[1_INVALID]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not a valid env var name"))
    end

    it "errors when an entry contains '=' (value form not allowed)" do
      lang[:env] = ["DOTNET_NOLOGO=1"]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not a valid env var name"))
    end

    it "errors when an entry contains a space" do
      lang[:env] = ["DOTNET NOLOGO"]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not a valid env var name"))
    end

    it "errors when an entry contains a hyphen" do
      lang[:env] = %w[DOTNET-NOLOGO]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not a valid env var name"))
    end

    it "errors when an entry is an empty string" do
      lang[:env] = [""]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("not a valid env var name"))
    end

    it "reports errors for each bad entry" do
      lang[:env] = %w[GOOD 1_BAD ALSO-BAD]
      errors = described_class.validate_language(lang)
      expect(errors.size).to eq(2)
    end
  end
end
