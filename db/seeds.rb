require_relative 'languages/archived'
require_relative 'languages/active'
require_relative 'languages/asset_validator'

# Phase 3 schema check — fail-fast on malformed `assets:` declarations.
# Per docs/superpowers/specs/2026-05-05-submission-assets-design.md.
asset_errors = @languages.flat_map { |lang| AssetValidator.validate_language(lang) }
if asset_errors.any?
  raise "active.rb asset validation failed:\n  " + asset_errors.join("\n  ")
end

ActiveRecord::Base.transaction do
  Language.unscoped.delete_all
  @languages.each_with_index do |language, index|
    Language.create(
      id: language[:id],
      name: language[:name],
      is_archived: language[:is_archived],
      source_file: language[:source_file],
      compile_cmd: language[:compile_cmd],
      run_cmd: language[:run_cmd],
      assets: language[:assets],
    )
  end
end
