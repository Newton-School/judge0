# Submission asset capture — design

**Date:** 2026-05-05
**Author:** gkapatia (with Claude)
**Repos touched:** `Newton-School/judge0`
**Target tag:** `newton-judge0:0.67`
**Phase 3 of the Verilog integration work** (see
`2026-05-02-iverilog-integration-design.md` for Phases 1–2).

## Goal

Capture binary/text artifacts produced inside the isolate sandbox during
a submission run (Verilog `.vcd` waveforms first, but the mechanism is
language-agnostic) and surface them via the judge0 API alongside
`stdout`/`stderr`/`status`. Today these files are wiped on
`isolate --cleanup` and never reach the caller.

The first concrete use case is Verilog: students need to see waveforms
to debug their DUT logic, and the testbench already produces a `.vcd`
file when it calls `$dumpfile` / `$dumpvars`. judge0 just needs to read
that file out of the box before cleanup, persist it, and expose it via
the API. Future use cases (C++ core dumps, JVM heap dumps, Python
`cProfile` traces, etc.) will reuse the same mechanism.

## Why this design and not stdout markers

An earlier draft proposed encoding the artifact as base64 in `stdout`
between markers (`===WAVE===` / `===END===`). That was rejected because
the platform's grader compares `stdout` against `expected_output`
byte-for-byte — any marker block in `stdout` would either break
grading or force every consumer (CLI, mobile, future clients) to learn
how to split the marker out before comparing.

A `stderr` variant (writing the marker block to stderr instead) was
considered as a smaller-effort alternative. It works mechanically, but
muddies stderr semantics (warnings + errors + base64 payload all in
one stream) and still requires every client to know the marker
convention. For v1 of a feature that's expected to grow (multiple
asset types per language, per-asset metadata, possibly per-asset
download endpoints), the cleaner separation of a dedicated DB-backed
mechanism wins.

## High-level model

A language definition in `db/languages/active.rb` may declare an
`assets` array. Each entry tells `IsolateJob` which file pattern to
look for in the box after `run_cmd` finishes and what to label the
captured file as:

```ruby
{
  id: 3005,
  name: "Verilog (Icarus 13.0)",
  ...
  run_cmd: "/bin/cat > tb.v && ... && /usr/local/iverilog-13.0/bin/vvp sim.vvp",
  assets: [
    { name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }
  ]
}
```

After `run_cmd` exits, `IsolateJob` walks the language's `assets`,
scans the box for files matching each `identification` regex, and
writes one `SubmissionAsset` row per matched file (capped at
`max_size` bytes). Rows persist as long as the parent submission does.
The API surfaces each asset's metadata in the submission JSON and
exposes the bytes via a dedicated endpoint.

Author opt-in is implicit: a testbench that doesn't call `$dumpfile`
produces no `.vcd`, the regex matches nothing, and no row is written.
Languages without an `assets:` array get no capture step at all.

## Schema

### `submission_assets` table

```ruby
class CreateSubmissionAssets < ActiveRecord::Migration[5.2]
  def change
    create_table :submission_assets do |t|
      t.references :submission,
                   foreign_key: { on_delete: :cascade },
                   null: false
      t.string :logical_name,    null: false   # "wave.vcd" from active.rb
      t.string :source_filename                 # actual matched filename
      t.text :data                              # base64-encoded, null when error set
      t.integer :size_bytes,     null: false   # raw byte size, even when error
      t.string :error                           # "size_limit_exceeded" | "read_error" | nil
      t.text :error_detail                      # human-readable detail
      t.timestamps
    end

    add_index :submission_assets, [:submission_id, :logical_name]
  end
end
```

Notes:

- **`text` column storing base64.** Keeps the data JSON-safe out of
  the box (no on-the-way-out encoding step), greppable in `psql` for
  debugging, and easy to migrate or dump-restore. Costs ~33% storage
  inflation vs raw bytes — at the volumes we expect (~10s of GB/year)
  not a concern.
- **`size_bytes` always reports the *raw* file size**, not the base64
  string size. This is what the cap is checked against and what the
  UI renders ("produced 55340 bytes — exceeded 20480 byte cap").
- **`logical_name` vs `source_filename`.** Logical name comes from the
  `assets:` declaration ("wave.vcd") and is the stable contract the
  platform UI keys off. Source filename is the actual matched file
  ("wave.vcd" or "custom.vcd" if the author called
  `$dumpfile("custom.vcd")`) — useful for download UX and debugging.
- **Composite index on `(submission_id, logical_name)`** supports the
  "give me asset X for submission Y" query path which is the dominant
  read pattern.
- **Cascade delete.** When a submission is pruned (judge0's existing
  cleanup), its assets go with it.

### `submissions.skip_assets` column

```ruby
class AddSkipAssetsToSubmissions < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :skip_assets, :boolean,
                                            default: false,
                                            null: false
  end
end
```

Persisted on the submission record (rather than passed through as a
job arg) so there's an audit trail of which submissions opted out and
the worker can read it directly off the submission row.

## `active.rb` schema additions

Each language entry may include an `assets:` array. Each asset
declaration is a hash with these fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | String | yes | Logical label stored on the row. Stable contract for clients. |
| `identification` | String (regex) | yes | Ruby regex matched against filenames in the box. Use single-quoted strings to avoid double-escape: `'\.vcd$'`. No implicit anchoring — author writes `^`/`$` if they want. |
| `max_size` | Integer (bytes) | no | Per-asset cap. Falls back to `MAX_MAX_ASSET_SIZE` when omitted. Clamped to `MAX_MAX_ASSET_SIZE` if it exceeds the global ceiling. |

Concrete Verilog 3005 entry after this spec lands:

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

The `run_cmd` itself stays exactly as it is post-Phase-2 — no marker
emission, no glob/encode logic in shell. All of that moves into Ruby.

## Configuration knobs (`judge0.conf`)

```
# ---- Asset capture (Phase 3) ----

# Hard ceiling on asset size in bytes. Acts as both:
#   - the default cap when a language's `assets:` declaration omits
#     `max_size`
#   - the absolute clamp on any per-language `max_size` (a language
#     cannot exceed this, only ask for less)
# Mirrors the role of MAX_MAX_MEMORY_LIMIT / MAX_MAX_FILE_SIZE.
MAX_MAX_ASSET_SIZE=20480
```

`Config::MAX_MAX_ASSET_SIZE` exposed as a Rails initializer read of
this env var. Single global knob, no per-deployment "default vs hard
ceiling" split — operationally simpler.

There is intentionally **no global feature gate** (no
`ENABLE_ASSETS`). Per-submission opt-out via `skip_assets` is the
caller's lever; per-language opt-in via `assets:` declaration is the
language designer's lever. If ops needs to effectively disable
capture deployment-wide, set `MAX_MAX_ASSET_SIZE=0` — every file then
exceeds the cap, so no `data` is stored (only error rows for
matches), and storage stays bounded.

## Capture rules

### Two-level decision

`IsolateJob#capture_assets` is called after `run_cmd` exits, before
`isolate --cleanup`. It returns early in two cases:

```ruby
def capture_assets
  return if @submission.skip_assets                                   # 1. caller opt-out
  return if language.assets.blank?                                    # 2. language opt-in
  ...
end
```

- **Caller opt-out (`skip_assets`):** per-submission preference set in
  the POST body. Useful for batch grading runs that don't need
  artifacts.
- **Language opt-in (`assets:` array):** implicit — a language without
  any asset declarations contributes no capture work.

There is no global ops gate. Asset capture is always available for
languages that declare it; callers that don't want it for a specific
submission set `skip_assets: true`. If ops needs an emergency clamp,
`MAX_MAX_ASSET_SIZE=0` makes every file an over-cap error (no `data`
stored).

### Match resolution

For each declared asset:

```ruby
pattern = Regexp.new(asset[:identification])
matches = Dir.entries(box_path).select { |f| pattern.match?(f) }.sort
matched_file = matches.first
```

- **Sorted alphabetically**, first match wins. Deterministic.
- **No match** → no row written. The "no row" rule is intentional: a
  problem that doesn't dump shouldn't get a per-asset row saying
  "didn't happen". A row exists ⇔ a file was identified.
- **Multiple matches.** For VCD this can't happen per IEEE 1364 (single
  `$dumpfile` per simulation); for future asset types it might. First
  alphabetically is safer than last-modified (less environment
  dependence). Future extension: `multi: true` declaration field
  to write a row per match.
- **Invalid regex** → IsolateJob logs a warning, skips that asset,
  submission still succeeds. Should never happen in practice because
  the lint script and seed-time check (below) reject invalid regexes
  before they reach a running container.

### Size cap resolution

```ruby
declared      = asset[:max_size]
hard_ceiling  = Config::MAX_MAX_ASSET_SIZE

effective_cap = [declared || hard_ceiling, hard_ceiling].min
```

Three cases:

| `asset[:max_size]` | Effective cap |
|---|---|
| nil (omitted) | `MAX_MAX_ASSET_SIZE` |
| Set, `≤ MAX_MAX_ASSET_SIZE` | the declared value |
| Set, `> MAX_MAX_ASSET_SIZE` | `MAX_MAX_ASSET_SIZE` (clamped) |

A language can ask for a *smaller* cap than the global ceiling; it
cannot ask for a larger one.

### Outcome rows

| State | Row written? | Fields populated |
|---|---|---|
| No file matches regex | no | — |
| Match within cap, readable | yes | `data`, `size_bytes`, `source_filename`, `error = nil` |
| Match exceeds cap | yes | `data = nil`, `size_bytes` = actual size, `source_filename`, `error = "size_limit_exceeded"`, `error_detail = "55340 bytes exceeds 20480 byte cap"` |
| Match unreadable (I/O error) | yes | `data = nil`, `size_bytes = 0` (or known size if statable), `error = "read_error"`, `error_detail` = OS message |

The error rows exist precisely so the platform UI can render
"waveform produced (55 KB) — exceeded 20 KB display cap" rather than
silently showing nothing.

## Validation

Asset declarations in `active.rb` are checked at two layers:

### Layer 1 — seed-time check

`db/seeds.rb` already loads `active.rb` and writes to the DB on every
container startup. We add a validation pass before insert; bad data
fails the seed → container won't start → bad config never reaches
production.

```ruby
@languages.each do |lang|
  Array(lang[:assets]).each do |asset|
    raise "active.rb: language #{lang[:id]} asset missing :name" \
      if asset[:name].to_s.empty?

    raise "active.rb: language #{lang[:id]} asset #{asset[:name].inspect} missing :identification" \
      if asset[:identification].to_s.empty?

    begin
      Regexp.new(asset[:identification])
    rescue RegexpError => e
      raise "active.rb: language #{lang[:id]} asset #{asset[:name].inspect} identification #{asset[:identification].inspect} not a valid regex: #{e.message}"
    end

    if asset.key?(:max_size)
      raise "active.rb: language #{lang[:id]} asset #{asset[:name].inspect} max_size must be positive Integer (got #{asset[:max_size].inspect})" \
        unless asset[:max_size].is_a?(Integer) && asset[:max_size] > 0
    end
  end
end
```

### Layer 2 — CLI lint (CI / pre-commit)

Standalone script that runs the same checks without touching the DB
or Rails framework:

```ruby
#!/usr/bin/env ruby
# bin/lint-active-rb — schema check for db/languages/active.rb

require_relative '../db/languages/active'

errors = []
@languages.each do |lang|
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
end

if errors.empty?
  puts "OK — #{@languages.count} languages, #{@languages.sum { |l| Array(l[:assets]).size }} asset declarations validated."
  exit 0
else
  warn "active.rb has #{errors.size} problem(s):"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
```

CI runs `bundle exec ruby bin/lint-active-rb` before the docker
build/push step. Caught at PR time, not at deploy time.

Both layers share validation logic. For v1 the duplication is small
enough to tolerate; if a third caller appears, extract to
`db/languages/asset_validator.rb` and have both call it.

## API surface

### `GET /submissions/:token` (extended)

Existing endpoint. Adds an `assets` field to the submission JSON when
requested via `fields=`:

```json
GET /submissions/<token>?fields=stdout,status,assets

{
  "stdout": "Time\t a b | y\n----------------\n0\t 0 0 | 0\n...",
  "status": { "id": 3, "description": "Accepted" },
  "assets": [
    {
      "logical_name": "wave.vcd",
      "source_filename": "wave.vcd",
      "size_bytes": 440,
      "error": null
    }
  ]
}
```

The `assets` field returns **metadata only**, no `data`. This keeps
typical submission JSON small (most consumers want to know "was a
waveform produced?" + size, not the bytes).

Over-cap example:

```json
{
  "assets": [
    {
      "logical_name": "wave.vcd",
      "source_filename": "wave.vcd",
      "size_bytes": 55340,
      "error": "size_limit_exceeded",
      "error_detail": "55340 bytes exceeds 20480 byte cap"
    }
  ]
}
```

### `GET /submissions/:token/assets/:logical_name` (new)

Returns the asset content. Data is stored base64-encoded in the DB
(see Schema), so:

- `Accept: application/json` (default) → `{ "data": "<base64>" }`
  served straight from the column, no transcoding.
- `Accept: application/octet-stream` → controller `Base64.decode64`s
  the column on the way out and ships the decoded bytes,
  `Content-Type: application/octet-stream` (future: per-asset
  content-type field).

404 when:
- Submission doesn't exist
- Asset row doesn't exist for that `logical_name`
- Asset row exists but `data` is null (because `error` is set)

In the 404-due-to-error case, the error description is already
visible in the submission GET response, so clients have enough
context.

## Toggles in practice

| Scenario | Required setup |
|---|---|
| Verilog problem with waveform | Testbench includes `$dumpfile`/`$dumpvars`. Default — works out of the box. |
| Caller doesn't want the waveform for this submission | POST body includes `"skip_assets": true`. |
| Ops needs to tighten the cap deployment-wide | Lower `MAX_MAX_ASSET_SIZE` in `judge0.conf`. Clamps existing language declarations. |
| Ops needs to effectively disable capture (incident response) | Set `MAX_MAX_ASSET_SIZE=0` — every file becomes over-cap, no data stored, only error rows recorded. |
| New asset type for an unrelated language | Add `assets: [...]` to that language's entry; lint passes; deploy. No core code changes. |

## Worked example: Verilog VCD round-trip

1. Student submits the AND-gate DUT (`source_code`) and the testbench
   from earlier (`stdin`) including `$dumpfile("wave.vcd"); $dumpvars(0, and_gate_tb);`.
2. judge0 enqueues `IsolateJob`. Box has `main.v` written from
   `source_code`.
3. `compile_cmd` parse-checks `main.v` alone — passes.
4. `run_cmd` does `cat > tb.v` (testbench from stdin), `iverilog
   -g2012 -o sim.vvp main.v tb.v`, `vvp sim.vvp`. vvp writes
   `wave.vcd` (440 bytes) to the box. stdout receives the truth
   table; vvp exits 0.
5. `IsolateJob#capture_assets` runs:
   - `submission.skip_assets` is false → continue.
   - Language 3005's `assets` is non-empty → continue.
   - For asset `{ name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }`:
     `effective_cap = min(20480, MAX_MAX_ASSET_SIZE) = 20480`. Scan
     box filenames against the regex → match `wave.vcd`. Stat the
     file: 440 bytes, ≤ 20480. Read bytes, base64-encode, write a
     `SubmissionAsset` row with `data = "JGRhdGUKCVR1ZS..."` (base64),
     `size_bytes = 440`, `source_filename = "wave.vcd"`,
     `error = nil`.
6. `isolate --cleanup` wipes the box.
7. Platform calls `GET /submissions/<token>?fields=stdout,status,assets`
   — sees the truth table in stdout, status Accepted, one asset
   metadata row.
8. Platform calls `GET /submissions/<token>/assets/wave.vcd` — gets
   the raw bytes, hands them to wavedrom-or-similar in the browser
   for inline rendering.

## Migration & rollout

Order:

1. Schema migrations (both: create `submission_assets`, add
   `submissions.skip_assets`).
2. `Config` initializer read of `MAX_MAX_ASSET_SIZE`; default 20480.
3. `IsolateJob#capture_assets` implementation.
4. Submissions controller: extend `fields=` allowlist with `assets`,
   accept `skip_assets` in POST body, mount the asset-bytes endpoint.
5. `active.rb`: add the `assets` field to the Verilog 3005 entry.
6. `db/seeds.rb`: validation block.
7. `bin/lint-active-rb`: standalone script.
8. CI: invoke `bin/lint-active-rb` before docker push.
9. `bin/newton-smoke-test`: extend Verilog 3005 case to verify a
   waveform is captured (submit testbench with `$dumpfile`, fetch
   submission with `fields=...,assets`, assert `assets[0].size_bytes
   > 0`).
10. Build + push `judge0-newton-compiler:0.29` (no change — already
    has iverilog).
11. Build + push `newton-judge0:0.67`. Bump compose, smoke locally,
    then staging.

Phase-3 docker tag bump is `0.66 → 0.67`. Bumping doesn't require a
compilers image rebuild — Phase-3 is judge0-only.

Backwards compatibility: existing submissions without an
`assets` row continue to work. The new `submissions.skip_assets`
column defaults to false, so old POST bodies (no `skip_assets`
field) get the new "capture if language has assets declared"
behavior automatically.

Production prerequisite remains the existing AL2 → AL2023 karpenter
NodeClass flip — same constraint as for 0.66, no new ops blocker
introduced by this spec.

## Risks and open items

- **Index size.** Once all Verilog problems start producing waveforms,
  `submission_assets` will accumulate ~10 KB / submission for the
  median problem. At 10k Verilog submissions/day that's ~100 MB/day,
  ~36 GB/year. Postgres handles this fine but worth budgeting in
  storage capacity planning. If volume grows, the natural next step
  is moving `data` to S3 with a pointer column (out of scope here —
  see "Out of scope" below).
- **No per-asset content-type yet.** v1 returns
  `application/octet-stream` from the bytes endpoint. If the platform
  UI needs to distinguish (e.g., text-rendered VCD vs binary core
  dump), add a `content_type` column to the asset declaration in a
  follow-up.
- **Pre-cap reads big files.** When a language's regex matches a
  500 MB file, IsolateJob reads `size_bytes` first via `File.size`
  (cheap), then only reads bytes when ≤ cap. So the over-cap path
  doesn't pull large files into memory. Worth confirming during
  implementation.
- **`skip_assets` enum vs boolean.** Currently boolean. If we ever
  want per-asset opt-out (skip waveform but still capture compile
  log), this becomes an array of logical names. Acceptable v1 wart;
  revisit if more asset types arrive.
- **Multi-match regex.** First alphabetically wins. If a future asset
  type genuinely produces multiple files (e.g., per-thread profiles),
  add `multi: true` to the declaration and write a row per match.
  Schema already supports multiple rows per (submission_id,
  logical_name).

## Out of scope (this spec)

- **External blob storage (S3 + pointer column).** Reasonable v2
  optimization once `submission_assets.data` row sizes start
  pressuring Postgres. Mechanism stays the same on the API side; the
  bytes endpoint just reads from S3 instead of the column. Not a
  concern at v1 scale.
- **Per-asset content-type / mime negotiation.** v1 ships
  `application/octet-stream` from the bytes endpoint. Add a
  `content_type` field to declarations when a real consumer needs it.
- **Authorization on the bytes endpoint.** Currently the `submissions`
  endpoint exposes data to anyone who knows the token; assets follow
  the same model for v1. If submissions ever get per-user auth, assets
  inherit that automatically.
- **GZIP-on-the-fly for the bytes endpoint.** VCD compresses ~40%; if
  bandwidth becomes a concern, add `Accept-Encoding: gzip` handling at
  the controller layer. Not needed at v1 scale.
- **Per-asset `multi: true`.** Future enhancement when an asset type
  legitimately produces multiple files.
- **Webhook on asset capture / asset failure.** Out of scope; consumers
  can poll the submission endpoint as today.
