# Pure-Ruby validator for db/languages/active.rb `env:` declarations.
#
# Used by:
#   - db/seeds.rb       — runs at container boot, fails fast on bad data
#   - bin/lint-active-rb — runs in CI, catches problems at PR time
#
# Deliberately depends on no Rails internals so the lint script can
# run without booting Rails. Mirrors AssetValidator's shape.
#
# Contract: `env:`, if present, is an Array of String. Each string is a
# bare environment-variable NAME (no `=value`) matching a permissive
# POSIX form `[A-Za-z_][A-Za-z0-9_]*`. Mixed case is intentional —
# .NET's canonical names (e.g. DOTNET_EnableWriteXorExecute) are not
# all-caps. The NAME-only form means values are sourced from the
# compiler image's Dockerfile ENV and propagated through isolate via
# `-E NAME`; active.rb just declares which names to propagate.
module EnvValidator
  module_function

  NAME_RE = /\A[A-Za-z_][A-Za-z0-9_]*\z/

  # Returns Array<String> of error messages (empty array on valid).
  def validate_language(lang)
    errors = []
    return errors unless lang.key?(:env)

    prefix = "lang #{lang[:id]} (#{lang[:name].inspect}) env"

    unless lang[:env].is_a?(Array)
      errors << "#{prefix}: must be an Array (got #{lang[:env].class})"
      return errors
    end

    lang[:env].each_with_index do |name, i|
      entry_prefix = "#{prefix}[#{i}]"

      unless name.is_a?(String)
        errors << "#{entry_prefix}: must be a String (got #{name.class})"
        next
      end

      unless name.match?(NAME_RE)
        errors << "#{entry_prefix}: #{name.inspect} is not a valid env var name"
      end
    end

    errors
  end
end
