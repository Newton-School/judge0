require_relative 'languages/archived'
require_relative 'languages/active'
require_relative 'languages/asset_validator'
require_relative 'languages/env_validator'

# Schema check — fail-fast on malformed `assets:` (Phase 3) or `env:`
# declarations. Both validators are pure-Ruby and run in CI too via
# bin/lint-active-rb.
schema_errors = @languages.flat_map do |lang|
  AssetValidator.validate_language(lang) + EnvValidator.validate_language(lang)
end
if schema_errors.any?
  raise "active.rb validation failed:\n  " + schema_errors.join("\n  ")
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
      env: language[:env],
    )
  end
end
