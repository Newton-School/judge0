# Pure-Ruby validator for db/languages/active.rb asset declarations.
#
# Used by:
#   - db/seeds.rb       — runs at container boot, fails fast on bad data
#   - bin/lint-active-rb — runs in CI, catches problems at PR time
#
# Deliberately depends on no Rails internals so the lint script can
# run without booting Rails (faster CI, fewer moving parts).
#
# Per docs/superpowers/specs/2026-05-05-submission-assets-design.md.
module AssetValidator
  module_function

  # Returns Array<String> of error messages (empty array on valid).
  def validate_language(lang)
    errors = []
    Array(lang[:assets]).each_with_index do |asset, i|
      prefix = "lang #{lang[:id]} (#{lang[:name].inspect}) asset[#{i}]"

      errors << "#{prefix}: missing :name"           if asset[:name].to_s.empty?
      errors << "#{prefix}: missing :identification" if asset[:identification].to_s.empty?

      if asset[:identification]
        begin
          Regexp.new(asset[:identification])
        rescue RegexpError => e
          errors << "#{prefix}: identification #{asset[:identification].inspect} not valid regex — #{e.message}"
        end
      end

      if asset.key?(:max_size) && !(asset[:max_size].is_a?(Integer) && asset[:max_size] > 0)
        errors << "#{prefix}: max_size must be positive Integer (got #{asset[:max_size].inspect})"
      end
    end
    errors
  end
end
