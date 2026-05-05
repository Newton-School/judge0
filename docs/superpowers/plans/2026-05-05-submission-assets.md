# Submission Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture artifacts (`.vcd` waveforms first; mechanism is language-agnostic) produced inside the isolate sandbox during a submission run, persist them in a new `submission_assets` table, and surface them via the judge0 API alongside `stdout`/`stderr`/`status`.

**Architecture:** A language definition in `db/languages/active.rb` may declare an `assets` array (each entry: `{ name:, identification:, max_size? }`, where `identification` is a Ruby regex). After `IsolateJob` runs `run_cmd` and before `isolate --cleanup` wipes the box, an `AssetCapture` service iterates the language's asset declarations, regex-matches files in the box, and writes one `SubmissionAsset` row per match (data base64-encoded into a `text` column, capped at `MAX_MAX_ASSET_SIZE`). Submissions get a new `skip_assets` boolean column for per-call opt-out. Two API surfaces: extended `GET /submissions/:token` (asset metadata when `fields=...,assets`) and a new `GET /submissions/:token/assets/:logical_name` (asset bytes).

**Tech Stack:** Rails 5.2, Ruby 2.7.8, Postgres 13, ActiveModel::Serializer for the API surface. No new gems.

**Spec:** `docs/superpowers/specs/2026-05-05-submission-assets-design.md`

---

## File Structure

### Created files

| Path | Responsibility |
|---|---|
| `db/migrate/20260505000001_create_submission_assets.rb` | New `submission_assets` table with FK + cascade delete |
| `db/migrate/20260505000002_add_skip_assets_to_submissions.rb` | Boolean column on `submissions` |
| `app/models/submission_asset.rb` | ActiveRecord model |
| `app/serializers/submission_asset_serializer.rb` | API representation (metadata only — `data` excluded) |
| `app/services/asset_capture.rb` | Capture logic: iterate declarations, match regex, read file, write row |
| `db/languages/asset_validator.rb` | Plain-Ruby validator for `assets:` declarations (no Rails dep) |
| `app/controllers/submission_assets_controller.rb` | Bytes endpoint |
| `bin/lint-active-rb` | Standalone CLI calling `AssetValidator` against `active.rb` |
| `spec/services/asset_capture_spec.rb` | Unit tests for capture |
| `spec/db/languages/asset_validator_spec.rb` | Unit tests for validator |

### Modified files

| Path | What changes |
|---|---|
| `judge0.conf` | New `MAX_MAX_ASSET_SIZE` knob |
| `app/helpers/config.rb` | New `Config::MAX_MAX_ASSET_SIZE` constant |
| `app/models/submission.rb` | `has_many :submission_assets`; `skip_assets` allowed in mass-assignment |
| `app/serializers/submission_serializer.rb` | New `assets` attribute returning metadata array |
| `app/jobs/isolate_job.rb` | Call `AssetCapture` after `run`, before `cleanup` |
| `app/controllers/submissions_controller.rb` | Accept `skip_assets` in POST body |
| `db/languages/active.rb` | Verilog 3005 entry gets `assets:` array |
| `db/seeds.rb` | Run `AssetValidator` before insert |
| `config/routes.rb` | New nested route for asset bytes |
| `bin/newton-smoke-test` | Verify asset metadata in Verilog smoke response |
| `CLAUDE.md` | Document the feature in Per-language tuning + Image is published as |

---

## Task 1: Create `submission_assets` table migration

**Files:**
- Create: `db/migrate/20260505000001_create_submission_assets.rb`

- [ ] **Step 1.1: Write the migration**

```ruby
class CreateSubmissionAssets < ActiveRecord::Migration[5.2]
  def change
    create_table :submission_assets do |t|
      t.references :submission,
                   foreign_key: { on_delete: :cascade },
                   null: false
      t.string :logical_name,    null: false
      t.string :source_filename
      t.text :data                            # base64-encoded bytes; null when error set
      t.integer :size_bytes,     null: false  # raw byte size of the matched file
      t.string :error                         # "size_limit_exceeded" | "read_error" | nil
      t.text :error_detail
      t.timestamps
    end

    add_index :submission_assets, [:submission_id, :logical_name]
  end
end
```

- [ ] **Step 1.2: Run the migration**

Run inside the judge0 container:
```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:migrate'
```
Expected: `== CreateSubmissionAssets: migrated (...)`. The table appears in `\dt` output.

- [ ] **Step 1.3: Sanity-check the schema**

```bash
docker compose -f docker-compose.dev.yml exec db psql -U judge0 -d judge0 -c '\d submission_assets'
```
Expected: columns include `submission_id`, `logical_name`, `source_filename`, `data`, `size_bytes`, `error`, `error_detail`, `created_at`, `updated_at`. Index on `(submission_id, logical_name)`.

- [ ] **Step 1.4: Commit**

```bash
git add db/migrate/20260505000001_create_submission_assets.rb db/schema.rb
git commit -m "Add submission_assets table"
```

---

## Task 2: Add `skip_assets` column to submissions

**Files:**
- Create: `db/migrate/20260505000002_add_skip_assets_to_submissions.rb`

- [ ] **Step 2.1: Write the migration**

```ruby
class AddSkipAssetsToSubmissions < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :skip_assets, :boolean, default: false, null: false
  end
end
```

- [ ] **Step 2.2: Run the migration**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:migrate'
```
Expected: `== AddSkipAssetsToSubmissions: migrated (...)`.

- [ ] **Step 2.3: Verify the column**

```bash
docker compose -f docker-compose.dev.yml exec db psql -U judge0 -d judge0 -c '\d submissions' | grep skip_assets
```
Expected: `skip_assets | boolean | not null default false`.

- [ ] **Step 2.4: Commit**

```bash
git add db/migrate/20260505000002_add_skip_assets_to_submissions.rb db/schema.rb
git commit -m "Add skip_assets column to submissions"
```

---

## Task 3: Add `MAX_MAX_ASSET_SIZE` to Config and judge0.conf

**Files:**
- Modify: `app/helpers/config.rb`
- Modify: `judge0.conf`

- [ ] **Step 3.1: Add the constant to `Config`**

In `app/helpers/config.rb`, add after the existing `MAX_MAX_*` constants (alongside `MAX_MAX_PROCESSES_AND_OR_THREADS`):

```ruby
  MAX_MAX_ASSET_SIZE = (ENV["MAX_MAX_ASSET_SIZE"].presence || 20480).to_i
```

- [ ] **Step 3.2: Add the env knob to `judge0.conf`**

Append to `judge0.conf` (find the section that has `MAX_MAX_FILE_SIZE` and add a new section beneath it):

```
# Hard ceiling on per-asset size (bytes). Used as both:
#   - the default cap when a language asset declaration omits :max_size
#   - the absolute clamp on any per-language max_size (a language
#     cannot exceed this; only ask for less)
# Mirrors the role of MAX_MAX_MEMORY_LIMIT / MAX_MAX_FILE_SIZE.
MAX_MAX_ASSET_SIZE=20480
```

- [ ] **Step 3.3: Reload config and verify**

The Rails container loads config on boot. Restart the judge0 service:
```bash
docker compose -f docker-compose.dev.yml restart judge0
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'source /api/scripts/load-config; echo "MAX_MAX_ASSET_SIZE=$MAX_MAX_ASSET_SIZE"'
```
Expected: `MAX_MAX_ASSET_SIZE=20480`.

- [ ] **Step 3.4: Commit**

```bash
git add app/helpers/config.rb judge0.conf
git commit -m "Add MAX_MAX_ASSET_SIZE config knob"
```

---

## Task 4: Create `SubmissionAsset` model and association

**Files:**
- Create: `app/models/submission_asset.rb`
- Modify: `app/models/submission.rb`

- [ ] **Step 4.1: Write the model**

`app/models/submission_asset.rb`:
```ruby
class SubmissionAsset < ApplicationRecord
  belongs_to :submission

  validates :logical_name,  presence: true
  validates :size_bytes,    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Convenience: rows with non-null `error` represent a capture attempt that
  # produced no bytes (e.g. exceeded MAX_MAX_ASSET_SIZE).
  scope :with_data, -> { where(error: nil).where.not(data: nil) }
end
```

- [ ] **Step 4.2: Add the association to Submission**

In `app/models/submission.rb`, find the model body and add after the existing associations (look for the `belongs_to :status` / `belongs_to :language` lines):

```ruby
  has_many :submission_assets, dependent: :destroy
```

Note: cascade on the DB side is already set; the `dependent: :destroy` keeps the Rails layer informed for callbacks/queries.

- [ ] **Step 4.3: Sanity-check via Rails console**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rails console <<<"puts SubmissionAsset.column_names.inspect"'
```
Expected: array including `"logical_name"`, `"data"`, `"size_bytes"`, `"error"`, `"submission_id"`.

- [ ] **Step 4.4: Commit**

```bash
git add app/models/submission_asset.rb app/models/submission.rb
git commit -m "Add SubmissionAsset model + association"
```

---

## Task 5: Create `AssetValidator` (no Rails dependency)

**Files:**
- Create: `db/languages/asset_validator.rb`
- Create: `spec/db/languages/asset_validator_spec.rb`

- [ ] **Step 5.1: Write the failing tests**

`spec/db/languages/asset_validator_spec.rb`:
```ruby
require "rails_helper"
require_relative "../../../db/languages/asset_validator"

RSpec.describe AssetValidator do
  describe ".validate_language" do
    let(:lang) { { id: 9999, name: "Test Lang" } }

    it "passes when no :assets array is present" do
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "passes for a well-formed asset" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }]
      errors = described_class.validate_language(lang)
      expect(errors).to be_empty
    end

    it "errors when :name is missing" do
      lang[:assets] = [{ identification: '\.vcd$' }]
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

    it "errors when :max_size is not a positive Integer" do
      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: -1 }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("max_size must be positive Integer"))

      lang[:assets] = [{ name: "wave.vcd", identification: '\.vcd$', max_size: "20480" }]
      errors = described_class.validate_language(lang)
      expect(errors).to include(a_string_including("max_size must be positive Integer"))
    end
  end
end
```

- [ ] **Step 5.2: Run the test, verify it fails**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && bundle exec rspec spec/db/languages/asset_validator_spec.rb'
```
Expected: load error or NameError because `AssetValidator` doesn't exist yet.

- [ ] **Step 5.3: Implement the validator**

`db/languages/asset_validator.rb`:
```ruby
# Pure-Ruby validator for db/languages/active.rb asset declarations.
# Used by db/seeds.rb (at container boot) and bin/lint-active-rb (CI).
# Deliberately depends on no Rails internals so the lint script can
# run without booting Rails.
module AssetValidator
  module_function

  # Returns Array<String> of error messages (empty on valid).
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
```

- [ ] **Step 5.4: Run tests, verify all pass**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && bundle exec rspec spec/db/languages/asset_validator_spec.rb'
```
Expected: 6 examples, 0 failures.

- [ ] **Step 5.5: Commit**

```bash
git add db/languages/asset_validator.rb spec/db/languages/asset_validator_spec.rb
git commit -m "Add AssetValidator for active.rb asset declarations"
```

---

## Task 6: Wire `AssetValidator` into `db/seeds.rb`

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 6.1: Find the load point**

Open `db/seeds.rb`. It loads `active.rb` and `archived.rb` then iterates `@languages` to insert/update Language records. We add the validation pass between load and insert.

- [ ] **Step 6.2: Add the validation call**

Near the top of `db/seeds.rb`, add the require:
```ruby
require_relative "languages/asset_validator"
```

After `@languages` is populated (after both `require_relative "languages/active"` and `require_relative "languages/archived"`), add the validation block:

```ruby
# Schema check — fail-fast on malformed asset declarations.
asset_errors = @languages.flat_map { |lang| AssetValidator.validate_language(lang) }
if asset_errors.any?
  raise "active.rb asset validation failed:\n  #{asset_errors.join("\n  ")}"
end
```

- [ ] **Step 6.3: Run seeds and verify it still passes**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:seed'
```
Expected: completes without raising. (No language has `:assets` yet, so the validator returns empty errors for all.)

- [ ] **Step 6.4: Negative test — temporarily inject a bad declaration**

Temporarily edit `db/languages/active.rb`, add a broken asset to (say) the Bash entry: `assets: [{ name: "x", identification: "[unclosed" }]`.

Run seed again:
```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:seed' 2>&1 | tail -3
```
Expected: `active.rb asset validation failed: ... not valid regex — ...`. Then **revert the temporary edit**.

- [ ] **Step 6.5: Commit**

```bash
git add db/seeds.rb
git commit -m "Validate active.rb asset declarations at seed time"
```

---

## Task 7: Standalone `bin/lint-active-rb` script

**Files:**
- Create: `bin/lint-active-rb`

- [ ] **Step 7.1: Write the script**

`bin/lint-active-rb`:
```ruby
#!/usr/bin/env ruby
# bin/lint-active-rb — schema check for db/languages/active.rb
#
# Usage:
#   bundle exec ruby bin/lint-active-rb
#
# Intended to run in CI before docker push so malformed asset
# declarations are caught at PR time, not at container boot.

require_relative "../db/languages/active"
require_relative "../db/languages/asset_validator"

errors = @languages.flat_map { |lang| AssetValidator.validate_language(lang) }

if errors.empty?
  decl_count = @languages.sum { |l| Array(l[:assets]).size }
  puts "OK — #{@languages.count} languages, #{decl_count} asset declarations validated."
  exit 0
else
  warn "active.rb has #{errors.size} problem(s):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
```

- [ ] **Step 7.2: Make it executable**

```bash
chmod +x bin/lint-active-rb
```

- [ ] **Step 7.3: Run it locally**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && ruby bin/lint-active-rb'
```
Expected: `OK — 21 languages, 0 asset declarations validated.` (No assets declared yet — Verilog gets one in Task 11.)

- [ ] **Step 7.4: Commit**

```bash
git add bin/lint-active-rb
git commit -m "Add bin/lint-active-rb CLI for asset declaration linting"
```

---

## Task 8: `AssetCapture` service (TDD)

**Files:**
- Create: `app/services/asset_capture.rb`
- Create: `spec/services/asset_capture_spec.rb`

- [ ] **Step 8.1: Write the failing tests**

`spec/services/asset_capture_spec.rb`:
```ruby
require "rails_helper"
require "tmpdir"
require "fileutils"
require "base64"

RSpec.describe AssetCapture do
  let(:submission) { Submission.create!(language: Language.first, source_code: "x") }

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

  it "stores base64 data and raw size when file is within cap" do
    raw = "$date\nFri\n$end\n"  # 18 bytes
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
end
```

- [ ] **Step 8.2: Run tests, verify they fail**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && bundle exec rspec spec/services/asset_capture_spec.rb'
```
Expected: NameError or LoadError on `AssetCapture` because the service doesn't exist yet.

- [ ] **Step 8.3: Implement the service**

`app/services/asset_capture.rb`:
```ruby
require "base64"

# Captures language-declared artifacts from the isolate box and persists
# them as SubmissionAsset rows. Called by IsolateJob after run_cmd
# completes, before `isolate --cleanup` wipes the box.
#
# Per spec docs/superpowers/specs/2026-05-05-submission-assets-design.md.
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
    return if pattern.nil?  # invalid regex — skip silently

    matched = Dir.entries(@box_path).select { |f| pattern.match?(f) }.sort.first
    return if matched.nil?  # no match — no row written

    file_path     = File.join(@box_path, matched)
    raw_size      = File.size(file_path)
    effective_cap = compute_cap(decl[:max_size])

    if raw_size > effective_cap
      @submission.submission_assets.create!(
        logical_name:    decl[:name],
        source_filename: matched,
        size_bytes:      raw_size,
        error:           "size_limit_exceeded",
        error_detail:    "#{raw_size} bytes exceeds #{effective_cap} byte cap"
      )
    else
      begin
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
end
```

- [ ] **Step 8.4: Run tests, verify all pass**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && bundle exec rspec spec/services/asset_capture_spec.rb'
```
Expected: 7 examples, 0 failures.

- [ ] **Step 8.5: Commit**

```bash
git add app/services/asset_capture.rb spec/services/asset_capture_spec.rb
git commit -m "Add AssetCapture service for box artifact persistence"
```

---

## Task 9: Wire `AssetCapture` into `IsolateJob`

**Files:**
- Modify: `app/jobs/isolate_job.rb`

- [ ] **Step 9.1: Locate the hook point**

Open `app/jobs/isolate_job.rb`. The `perform` method runs `compile`, `reset_cgroup_for_run`, `run`, `verify`, then `cleanup` — `cleanup` runs `isolate --cleanup` and the box gets wiped. We hook *between `verify` and `cleanup`*. Around line ~37 in the run loop:

```ruby
      reset_cgroup_for_run
      run
      verify

      time << submission.time
      memory << submission.memory

      cleanup        # ← we add a call to capture_assets immediately before this
      break if submission.status != Status.ac
```

- [ ] **Step 9.2: Add the capture call**

Replace the relevant block in `perform`:

```ruby
      reset_cgroup_for_run
      run
      verify

      time << submission.time
      memory << submission.memory

      capture_assets
      cleanup
      break if submission.status != Status.ac
```

Also: add the `capture_assets` private method at the bottom of the file (alongside other privates like `cleanup`):

```ruby
  def capture_assets
    return if submission.skip_assets
    return if submission.language.assets.blank?

    AssetCapture.new(
      box_path:     boxdir,
      submission:   submission,
      declarations: submission.language.assets
    ).call
  rescue StandardError => e
    # Capture failure must not break the submission. Log and move on;
    # cleanup will run regardless.
    Rails.logger.error("AssetCapture failed for submission #{submission.id}: #{e.class} #{e.message}")
  end
```

The early-return guards mirror the spec's two-level decision (caller opt-out + language opt-in). The `rescue` ensures a problem in capture never breaks grading.

- [ ] **Step 9.3: Sanity-check it parses**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && ruby -c app/jobs/isolate_job.rb'
```
Expected: `Syntax OK`.

- [ ] **Step 9.4: Commit**

```bash
git add app/jobs/isolate_job.rb
git commit -m "IsolateJob: capture declared assets before cleanup"
```

---

## Task 10: Expose `assets` field via `Submission#language` accessor

The `Language` model's `assets` is a Postgres `text` column today storing the `assets:` array as YAML/JSON in seeds.rb (or it doesn't exist yet, depending on how `active.rb` is loaded into the DB). Investigate.

**Files:**
- Modify: `db/seeds.rb` (if `assets` is not yet persisted)
- Modify: `app/models/language.rb` (if necessary)

- [ ] **Step 10.1: Determine current Language schema**

```bash
docker compose -f docker-compose.dev.yml exec db psql -U judge0 -d judge0 -c '\d languages'
```
Note whether an `assets` column exists.

- [ ] **Step 10.2: If `assets` does NOT exist, add a migration**

Create `db/migrate/20260505000003_add_assets_to_languages.rb`:
```ruby
class AddAssetsToLanguages < ActiveRecord::Migration[5.2]
  def change
    add_column :languages, :assets, :text  # serialized YAML
  end
end
```

Run: `rake db:migrate` inside the container. Then in `app/models/language.rb`, add:
```ruby
  serialize :assets
```

If the column already exists, skip the migration and confirm `serialize :assets` is present.

- [ ] **Step 10.3: Update `db/seeds.rb` to persist `assets`**

In `db/seeds.rb`, find the loop where Language records are created/updated. The existing code likely does something like `Language.find_or_create_by(id: lang[:id]).update(name: lang[:name], ...)`. Add `assets: lang[:assets]` to the update hash so `Language#assets` reflects the active.rb declaration:

```ruby
Language.find_or_create_by(id: lang[:id]).update(
  name:         lang[:name],
  is_archived:  lang[:is_archived],
  source_file:  lang[:source_file],
  compile_cmd:  lang[:compile_cmd],
  run_cmd:      lang[:run_cmd],
  assets:       lang[:assets]   # nil for languages that don't declare any
)
```

(Match the existing seed pattern; the relevant fields will already be there. Just add `assets:`.)

- [ ] **Step 10.4: Re-seed and verify**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:seed'
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rails runner "puts Language.find(46).assets.inspect"'
```
Expected: `nil` (Bash 46 has no assets declared yet).

- [ ] **Step 10.5: Commit**

```bash
git add db/seeds.rb app/models/language.rb db/migrate/20260505000003_add_assets_to_languages.rb db/schema.rb
git commit -m "Persist Language#assets from active.rb"
```

---

## Task 11: Declare `assets:` for Verilog 3005

**Files:**
- Modify: `db/languages/active.rb`

- [ ] **Step 11.1: Add the assets field**

In `db/languages/active.rb`, find the Verilog 3005 entry and add `assets:` after `run_cmd`:

```ruby
  {
    id: 3005,
    name: "Verilog (Icarus 13.0)",
    is_archived: false,
    source_file: "main.v",
    compile_cmd: "/usr/local/iverilog-13.0/bin/iverilog -g2012 -tnull %s main.v",
    run_cmd: "/bin/cat > tb.v && /usr/local/iverilog-13.0/bin/iverilog -g2012 -o sim.vvp main.v tb.v && /usr/local/iverilog-13.0/bin/vvp sim.vvp",
    assets: [
      { name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }
    ]
  }
```

- [ ] **Step 11.2: Run the lint to confirm**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && ruby bin/lint-active-rb'
```
Expected: `OK — 21 languages, 1 asset declarations validated.`

- [ ] **Step 11.3: Re-seed**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rake db:seed'
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rails runner "puts Language.find(3005).assets.inspect"'
```
Expected: `[{:name=>"wave.vcd", :identification=>"\\.vcd$", :max_size=>20480}]`.

- [ ] **Step 11.4: Commit**

```bash
git add db/languages/active.rb
git commit -m "Declare wave.vcd asset for Verilog 3005"
```

---

## Task 12: Accept `skip_assets` in submission POST body

**Files:**
- Modify: `app/controllers/submissions_controller.rb`

- [ ] **Step 12.1: Locate the parameter list**

In `app/controllers/submissions_controller.rb`, find `submission_params` (private method that calls `params.permit(...)`).

- [ ] **Step 12.2: Add `:skip_assets` to permitted params**

Add `:skip_assets` to the list of permitted attributes:
```ruby
  def submission_params
    params.permit(:source_code, :language_id, :additional_files,
                  :compiler_options, :command_line_arguments,
                  :stdin, :expected_output, :cpu_time_limit,
                  # ... existing list ...
                  :skip_assets)
  end
```

(Match the existing structure; add `:skip_assets` to whatever list is already there.)

- [ ] **Step 12.3: Manual smoke check via curl**

After restarting the judge0 service:
```bash
curl -s -X POST 'http://localhost:2358/submissions?wait=false&fields=token' \
  -H 'Content-Type: application/json' \
  -d '{"language_id": 46, "source_code": "echo hi", "skip_assets": true}' | jq .
```
Expected: `{ "token": "..." }`. Then check the persisted value:
```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rails runner "puts Submission.last.skip_assets.inspect"'
```
Expected: `true`.

- [ ] **Step 12.4: Commit**

```bash
git add app/controllers/submissions_controller.rb
git commit -m "Accept skip_assets in submission POST body"
```

---

## Task 13: `SubmissionAssetSerializer` + assets field on submission JSON

**Files:**
- Create: `app/serializers/submission_asset_serializer.rb`
- Modify: `app/serializers/submission_serializer.rb`

- [ ] **Step 13.1: Write the asset serializer (metadata only — no data)**

`app/serializers/submission_asset_serializer.rb`:
```ruby
class SubmissionAssetSerializer < ActiveModel::Serializer
  attributes :logical_name, :source_filename, :size_bytes, :error, :error_detail
end
```

- [ ] **Step 13.2: Add `assets` to the submission serializer**

In `app/serializers/submission_serializer.rb`, after the existing `attributes` line and method definitions, add:

```ruby
  attribute :assets

  def assets
    object.submission_assets.map { |a| SubmissionAssetSerializer.new(a).attributes }
  end
```

This returns an array of metadata hashes — no `data`. The bytes endpoint (Task 14) is the only way to fetch the `data`.

- [ ] **Step 13.3: Manual smoke**

Submit a Bash hello-world (no assets declared for Bash) and request `assets`:
```bash
TOKEN=$(curl -s -X POST 'http://localhost:2358/submissions?wait=true&fields=token' \
  -H 'Content-Type: application/json' \
  -d '{"language_id": 46, "source_code": "echo hi"}' | jq -r .token)
curl -s "http://localhost:2358/submissions/$TOKEN?fields=token,assets" | jq .
```
Expected: `{ "token": "...", "assets": [] }`.

- [ ] **Step 13.4: Commit**

```bash
git add app/serializers/submission_asset_serializer.rb app/serializers/submission_serializer.rb
git commit -m "Expose submission assets metadata via SubmissionSerializer"
```

---

## Task 14: Asset bytes endpoint

**Files:**
- Create: `app/controllers/submission_assets_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 14.1: Write the controller**

`app/controllers/submission_assets_controller.rb`:
```ruby
require "base64"

class SubmissionAssetsController < ApplicationController
  before_action :set_submission_and_asset

  # GET /submissions/:submission_token/assets/:logical_name
  # Default response: { "data": "<base64>" } JSON.
  # When Accept: application/octet-stream, ships decoded bytes.
  def show
    if @asset.data.nil?
      head :not_found
      return
    end

    if request.format.symbol == :octet_stream || request.headers["Accept"] == "application/octet-stream"
      send_data Base64.decode64(@asset.data),
                type: "application/octet-stream",
                disposition: "attachment",
                filename: (@asset.source_filename.presence || @asset.logical_name)
    else
      render json: { data: @asset.data }
    end
  end

  private

  def set_submission_and_asset
    submission = Submission.find_by!(token: params[:submission_token])
    @asset     = submission.submission_assets.find_by!(logical_name: params[:logical_name])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
```

- [ ] **Step 14.2: Add the nested route**

In `config/routes.rb`, change the existing submissions resource to add a member route:

```ruby
  resources :submissions, only: [:index, :show, :create, :destroy], param: :token do
    post 'batch', to: 'submissions#batch_create', on: :collection
    get 'batch', to: 'submissions#batch_show', on: :collection

    get 'assets/:logical_name',
        to: 'submission_assets#show',
        constraints: { logical_name: /[^\/]+/ },
        as: :asset
  end
```

The `constraints: { logical_name: /[^\/]+/ }` allows dots and other characters in filenames (e.g., `wave.vcd`).

- [ ] **Step 14.3: Verify routes**

```bash
docker compose -f docker-compose.dev.yml exec judge0 bash -c 'cd /api && rails routes | grep submission_asset'
```
Expected: a route mapping `GET /submissions/:submission_token/assets/:logical_name` to `submission_assets#show`.

- [ ] **Step 14.4: Manual smoke (no asset present yet)**

```bash
TOKEN=$(curl -s -X POST 'http://localhost:2358/submissions?wait=true&fields=token' \
  -H 'Content-Type: application/json' \
  -d '{"language_id": 46, "source_code": "echo hi"}' | jq -r .token)
curl -s -o /dev/null -w '%{http_code}\n' "http://localhost:2358/submissions/$TOKEN/assets/wave.vcd"
```
Expected: `404` (no asset row exists for the bash submission).

- [ ] **Step 14.5: Commit**

```bash
git add app/controllers/submission_assets_controller.rb config/routes.rb
git commit -m "Add asset bytes endpoint"
```

---

## Task 15: End-to-end Verilog asset test

Submit a Verilog DUT + testbench-with-`$dumpfile` via the API, fetch the resulting submission with `fields=...,assets`, and verify the asset metadata + bytes endpoint.

**Files:**
- Modify: `bin/newton-smoke-test`

- [ ] **Step 15.1: Add a new test snippet for Verilog with waveform**

In `bin/newton-smoke-test`, add a new section after the existing Verilog cases. First the source snippets:

```bash
SRC_VERILOG_WAVE='module and_gate(input wire a, input wire b, output wire y);
  assign y = a & b;
endmodule'

STDIN_VERILOG_WAVE='`timescale 1ns/1ps
module and_gate_tb;
  reg a; reg b; wire y;
  and_gate uut (.a(a), .b(b), .y(y));
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, and_gate_tb);
    a = 0; b = 0; #10;
    a = 0; b = 1; #10;
    a = 1; b = 0; #10;
    a = 1; b = 1; #10;
    $display("Hello, Newton!");
    $finish(0);
  end
endmodule'
```

- [ ] **Step 15.2: Add a new helper `t_stdin_with_asset` that asserts asset metadata**

In `bin/newton-smoke-test` (alongside the existing `t_stdin`), add:

```bash
# t_stdin_with_asset <name> <language_id> <source_code> <stdin> <expected_substring> <asset_logical_name>
# Same as t_stdin but additionally fetches submission with fields=...,assets,
# checks the named asset is present with size_bytes > 0 and error == null,
# and confirms GET /submissions/:token/assets/:logical_name returns 200 with non-empty body.
t_stdin_with_asset() {
    local name="$1" lid="$2" src="$3" stdin="$4" expected="$5" asset_name="$6"
    local payload resp token assets_json size err

    payload="$(jq -nc --arg sc "$src" --arg si "$stdin" --argjson lid "$lid" \
        '{language_id:$lid, source_code:$sc, stdin:$si}')"
    resp="$(curl -s -X POST "${URL}/submissions?wait=true&fields=token,stdout,stderr,status,message,compile_output,assets" \
        -H 'Content-Type: application/json' -d "$payload")"

    token="$(echo "$resp" | jq -r '.token // empty')"
    _check_resp "$name" "$lid" "$expected" "$resp"

    if [[ -z "$token" ]]; then
        printf "  \033[31mFAIL\033[0m  %s asset check skipped (no token)\n" "$name"
        FAIL=$((FAIL+1))
        FAILED+=("$name asset (no token)")
        return
    fi

    assets_json="$(echo "$resp" | jq -c --arg n "$asset_name" '.assets // [] | map(select(.logical_name == $n)) | .[0] // {}')"
    size="$(echo "$assets_json" | jq -r '.size_bytes // 0')"
    err="$(echo "$assets_json" | jq -r '.error // empty')"

    if [[ -n "$err" || "$size" -le 0 ]]; then
        printf "  \033[31mFAIL\033[0m  %s asset check  size=%s err=%s\n" "$name" "$size" "$err"
        FAIL=$((FAIL+1))
        FAILED+=("$name asset (size=$size, err=$err)")
        return
    fi

    local bytes_status
    bytes_status="$(curl -s -o /dev/null -w '%{http_code}' "${URL}/submissions/$token/assets/$asset_name")"
    if [[ "$bytes_status" != "200" ]]; then
        printf "  \033[31mFAIL\033[0m  %s asset bytes endpoint http=%s\n" "$name" "$bytes_status"
        FAIL=$((FAIL+1))
        FAILED+=("$name asset bytes (http $bytes_status)")
        return
    fi

    printf "  \033[32mPASS\033[0m  %s asset (size=%s)\n" "$name" "$size"
    PASS=$((PASS+1))
}
```

- [ ] **Step 15.3: Call the helper for the Verilog wave case**

In the Newton extras section of `bin/newton-smoke-test` (after the existing Verilog calls), add:

```bash
# Verilog with waveform: testbench includes $dumpfile + $dumpvars; we
# expect a wave.vcd asset to be captured and surfaced via the API.
t_stdin_with_asset "Verilog 3005 with wave.vcd asset" 3005 \
    "$SRC_VERILOG_WAVE" "$STDIN_VERILOG_WAVE" "$EXPECTED" "wave.vcd"
```

- [ ] **Step 15.4: Run the smoke test against local dev**

```bash
JUDGE0_URL=http://localhost:2358 ./bin/newton-smoke-test
```
Expected count: previously 23/0/0; now 24/0/0 on amd64 (one new PASS for the asset case). On arm64, was 21/0/2; now 22/0/2.

- [ ] **Step 15.5: Commit**

```bash
git add bin/newton-smoke-test
git commit -m "Smoke test: verify Verilog 3005 captures wave.vcd asset end-to-end"
```

---

## Task 16: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 16.1: Update smoke counts**

In the "End-to-end smoke test" section, change "23 PASS / 0 FAIL / 0 SKIP on amd64; 21 PASS / 0 FAIL / 2 SKIP on arm64" to:

```
**24 PASS / 0 FAIL / 0 SKIP** on amd64; **22 PASS / 0 FAIL / 2 SKIP** on
arm64 (NASM and FreeBASIC are amd64-only upstream).
```

- [ ] **Step 16.2: Add `MAX_MAX_ASSET_SIZE` to the judge0.conf knobs table**

In the "judge0.conf knobs" table, append a row:

```
| `MAX_MAX_ASSET_SIZE` | – (new in 0.67) | **20480** (20 KB) | per-asset cap; clamps language declarations |
```

- [ ] **Step 16.3: Add a Per-language tuning note**

In "Per-language tuning conventions", append a bullet after the existing Verilog 3005 note:

```
- **Submission assets (Phase 3 / 0.67+).** Languages may declare an
  `assets:` array in `active.rb` (e.g., Verilog 3005 declares
  `wave.vcd`). After `run_cmd` exits, `IsolateJob` calls
  `AssetCapture` to glob the box for matching files and persist them
  as `submission_assets` rows (base64 in a `text` column, capped per
  declaration / `MAX_MAX_ASSET_SIZE`). API exposure: extended submission
  GET (metadata via `fields=...,assets`) + dedicated bytes endpoint
  `GET /submissions/:token/assets/:logical_name`. Per-submission
  opt-out via `skip_assets: true` in the POST body. See
  `docs/superpowers/specs/2026-05-05-submission-assets-design.md`.
```

- [ ] **Step 16.4: Bump the published-tag note**

In "Image is published as", change `Current tag: **0.66**` to:

```
- Current tag: **`0.67`** — adds Phase 3 submission-assets capture
  (Verilog 3005 declares `wave.vcd`; framework is language-agnostic).
  Smoke target 24/0/0 on amd64.
```

Update the chronology range from `0.53 → 0.66` to `0.53 → 0.67`.

- [ ] **Step 16.5: Bump the AL2-prereq line**

In the same section, the existing line `**Before bumping prod to 0.66:** prod nodes still run Amazon Linux 2 (cgroup v1).` becomes:

```
- **Before bumping prod to 0.67:** prod nodes still run Amazon Linux 2 (cgroup v1).
```

- [ ] **Step 16.6: Commit**

```bash
git add CLAUDE.md
git commit -m "Document Phase 3 submission assets in CLAUDE.md"
```

---

## Task 17: Bump version refs in compose + Postman

**Files:**
- Modify: `docker-compose.dev.yml`
- Modify: `bin/newton-postman.json`

- [ ] **Step 17.1: Bump compose tag**

In `docker-compose.dev.yml`, change `:0.66` → `:0.67` on the `judge0` service `image:` line and in the build-command comment above it.

- [ ] **Step 17.2: Bump postman collection name**

In `bin/newton-postman.json`, change `"Newton Judge0 — All Languages (0.66)"` to `"Newton Judge0 — All Languages (0.67)"`.

- [ ] **Step 17.3: Commit**

```bash
git add docker-compose.dev.yml bin/newton-postman.json
git commit -m "Bump tag refs 0.66 → 0.67"
```

---

## Task 18: Build, smoke locally, push staging

**Files:** none — this is a deploy gate.

- [ ] **Step 18.1: arm64 dev build (Mac)**

```bash
docker buildx build --platform linux/arm64 \
  -f NewtonDockerfile \
  -t newtonschool/newton-judge0:0.67 \
  --load .
```

Expected: build completes, ~15–20 min from scratch.

- [ ] **Step 18.2: Bring up dev stack with the new image**

```bash
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d judge0 db redis redis-sidecar
docker compose -f docker-compose.dev.yml exec -d --privileged judge0 \
  bash -c 'source /api/scripts/load-config; cd /api && rake resque:workers QUEUE=*'
sleep 20
```

- [ ] **Step 18.3: arm64 smoke**

```bash
JUDGE0_URL=http://localhost:2358 ./bin/newton-smoke-test
```
Expected: **22 PASS / 0 FAIL / 2 SKIP** (arm64). Includes the new asset case.

- [ ] **Step 18.4: amd64 EC2 build (in tmux)**

On EC2:
```bash
git pull origin <branch>
docker buildx build --platform linux/amd64 \
  -f NewtonDockerfile \
  -t newtonschool/newton-judge0:0.67 \
  --load .
```
Then bring up the same stack and run the smoke. Expected: **24 PASS / 0 FAIL / 0 SKIP**.

- [ ] **Step 18.5: Push to Docker Hub**

```bash
docker push newtonschool/newton-judge0:0.67
```

- [ ] **Step 18.6: Deploy to staging and smoke against it**

Use whatever the existing staging deploy mechanism is (kubectl / ECR push). Then:
```bash
JUDGE0_URL=https://judge0-public.staging-newtonschool.co ./bin/newton-smoke-test
```
Expected: **24/0/0** on the staging amd64 cluster.

---

## Self-review

**Spec coverage:**
- ✅ `submission_assets` table schema (Task 1)
- ✅ `submissions.skip_assets` column (Task 2)
- ✅ `MAX_MAX_ASSET_SIZE` config (Task 3)
- ✅ Model + association (Task 4)
- ✅ AssetValidator + tests (Task 5)
- ✅ Seed-time validation (Task 6)
- ✅ `bin/lint-active-rb` CLI (Task 7)
- ✅ AssetCapture service + tests (Task 8)
- ✅ IsolateJob hook with two-level decision (Task 9)
- ✅ Language#assets column persistence (Task 10)
- ✅ Verilog 3005 asset declaration (Task 11)
- ✅ `skip_assets` in POST body (Task 12)
- ✅ Submission/Asset serializers (Task 13)
- ✅ Bytes endpoint + route (Task 14)
- ✅ End-to-end smoke (Task 15)
- ✅ CLAUDE.md docs (Task 16)
- ✅ Tag bumps (Task 17)
- ✅ Build + smoke + push (Task 18)

**Placeholder scan:** No "TBD" / "TODO" / "implement later". Every code step has full code; every test step has full test code.

**Type consistency:**
- `AssetCapture` initializer keyword args: `box_path`, `submission`, `declarations` — used identically in the service implementation, the spec, and IsolateJob.
- `SubmissionAsset` columns: `logical_name`, `source_filename`, `data`, `size_bytes`, `error`, `error_detail` — identical across migration, model, serializer, and AssetCapture.
- `Config::MAX_MAX_ASSET_SIZE` — same name in `Config` constant, `judge0.conf` env var, and AssetCapture reference.
- `skip_assets` — same name as boolean column, model attribute, and POST param.
- Asset declaration field names: `name`, `identification`, `max_size` — same in spec, validator, capture service, and active.rb.

---

Plan complete and saved to `docs/superpowers/plans/2026-05-05-submission-assets.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
