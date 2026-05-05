# judge0 — Newton School fork

Rails 5.2 API for sandboxed code execution. Forked from `judge0/judge0`
(upstream v1.13). Layered on top of `newtonschool/judge0-newton-compiler`
(see `Newton-School/compilers`) which provides every compiler/interpreter
plus the `isolate` sandbox.

## Stack

| Component | Version | Why |
|---|---|---|
| App runtime Ruby | **2.7.8** | Stays on Rails 5.2; OpenSSL 1.1.1w is built inline because bookworm only ships OpenSSL 3 and Ruby 2.7's bundled openssl extension can't build against 3 |
| Rails | 5.2.4.3 | Frozen — major upgrade out of scope of current modernisation |
| Postgres | 13 (dev) | Production uses managed Postgres |
| Redis | 6.0 + 6.2.6 sidecar | sidecar = secondary cache (separate db) |
| Resque + Resque-scheduler | 2.0 / 4.4 | submission queue |
| Compiler base | `newtonschool/judge0-newton-compiler:0.29` | what we layer on |
| Sandbox | `isolate` v2.0 in **cgroup v2 mode** (`docker-entrypoint.sh` sets up the hierarchy at startup) | from compilers image |

The Rails app's Ruby (`/usr/local/ruby-2.7.8`, installed in
`NewtonDockerfile`) is **decoupled** from the Ruby that student
submissions use (`/usr/local/ruby-3.3.6`, language id 72, comes from the
compilers image). Don't conflate them.

## Repo layout you will care about

```
.
├── Dockerfile                       # upstream layout, frozen
├── NewtonDockerfile                 # Newton's production image — USE THIS
├── docker-compose.dev.yml           # dev-only stack; prod deploys the single image
├── docker-entrypoint.sh             # `cron && exec "$@"` — keeps cron alive
├── judge0.conf                      # all sandbox knobs (memory, time, processes, file size)
├── scripts/
│   ├── server                       # `rails db:create db:migrate db:seed && rails s`
│   ├── workers                      # `rake resque:scheduler && rake resque:workers`
│   ├── load-config                  # sources judge0.conf, sets RAILS env
│   └── dev/{shell,bundle,clean,...} # dev helpers
├── bin/
│   ├── newton-smoke-test            # 20-language end-to-end smoke test (post-trim)
│   └── agricius                     # release tarball generator (rare use)
├── db/
│   ├── languages/active.rb          # canonical language id → command map
│   ├── languages/archived.rb        # historical/dropped languages
│   ├── seeds.rb                     # loads active.rb + archived.rb into DB
│   └── migrate/                     # rails migrations (don't add new ones lightly)
├── app/jobs/isolate_job.rb          # the sandbox runner — most complex Ruby in the repo
├── app/controllers/submissions_controller.rb
├── cron/{clear_cache,telemetry}     # baked-in cron entries; expect /api/tmp/environment from scripts/load-config
└── config/                          # standard Rails 5 config layout
```

## Languages: how a submission flows

1. `POST /submissions` → `submissions_controller.rb` validates + persists.
2. Resque enqueues `IsolateJob` with the submission token.
3. `IsolateJob#perform`:
   - Calls `isolate -b <id> --init` to create `/var/local/lib/isolate/<id>/box`.
   - Writes the source from `submission.source_code` to `box/<source_file>`.
   - Runs the language's `compile_cmd` (if any) inside isolate via `--run`.
   - Runs the `run_cmd` inside isolate.
   - Captures stdout/stderr/metadata.
   - `isolate --cleanup` afterwards.
4. The submission row's `status_id` is updated; the API returns it.

`db/languages/active.rb` is the **single source of truth** for which
language ids exist and what they invoke. Editing it requires a
`rails db:seed` to take effect (which `scripts/server` runs on startup).

## Per-language tuning conventions

- **C / Fortran compile commands** carry lenient flags so GCC-9-era
  student code still compiles on GCC 14 (which promoted four warnings to
  errors). Don't strip these:
  ```
  -Wno-error=implicit-function-declaration
  -Wno-error=implicit-int
  -Wno-error=int-conversion
  -Wno-error=incompatible-pointer-types
  ```
  And `-fallow-argument-mismatch` for Fortran (gfortran 10+ broke
  argument-mismatch tolerance).
- **JVM-based languages** (Java, MARS) pass `-XX:ActiveProcessorCount=2`
  (or set `JAVA_OPTS` for launcher scripts). Without this the JVM sees
  host nproc and spawns threadpools that hit `RLIMIT_NPROC` inside the
  sandbox → `pthread_create EAGAIN`.
- **Kotlin compile (id 78)** carries explicit JVM heap caps via `-J`
  flags on `kotlinc`:
  ```
  -J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC
  ```
  Reason: `IsolateJob#compile` hardcodes the compile cgroup's
  `--cg-mem` to `Config::MAX_MEMORY_LIMIT` (NOT the per-submission
  `memory_limit`), so the compile step is fixed at 500 MB on staging.
  Default G1GC + uncapped metaspace pushes total JVM footprint past
  500 MB even on hello-world and the cgroup OOM-killer SIGKILLs the
  java subprocess. UseSerialGC is not optional — it's the difference
  between a ~480 MB and a ~600 MB resident footprint.
- **GCC id 50 (C) / 54 (C++)** are the only C/C++ toolchain entries in
  active.rb (both point to `/usr/local/gcc-9.5.0/...`). Ids 3003/3004
  (GCC 14) live in `archived.rb`. See `compilers/CLAUDE.md` for why the
  image ships only 9.5.
- **Verilog id 3005 (Icarus 13.0)** uses an unusual two-file submission
  model: `source_code` is the student's DUT, `stdin` is the
  instructor-supplied testbench. `compile_cmd` parse-checks the DUT
  alone with `iverilog -tnull` (so DUT syntax errors go to the Compile
  Error bucket); `run_cmd` does `cat > tb.v && iverilog ... && vvp ...`
  and forwards vvp's stdout verbatim — no filtering. Problem authors
  must capture `expected_output` by running their testbench and
  including everything vvp prints, including the
  `tb.v:N: $finish called at T (1s)` epilogue (or use `$finish(0);` in
  the testbench to suppress that line at source). Full design rationale
  in `docs/superpowers/specs/2026-05-02-iverilog-integration-design.md`.
- **Submission assets (Phase 3, new in 0.67).** Languages may declare
  an `assets:` array in `active.rb` (Verilog 3005 declares `wave.vcd`
  with regex `\.vcd$`). After `run_cmd` exits, `IsolateJob` calls
  `AssetCapture` to glob the box for matching files and persist them
  as `submission_assets` rows (base64 in a `text` column, capped per
  declaration / `MAX_MAX_ASSET_SIZE`). Two-level decision: per-call
  opt-out via `skip_assets: true` in the POST body, plus implicit
  per-language opt-in (no `assets:` array → no capture work).
  Validation runs at seed time (fails container boot on bad regex)
  and via `bin/lint-active-rb` (CI gate). API: extended submission
  GET returns asset metadata when `fields=...,assets`; bytes via
  `GET /submissions/:token/assets/:logical_name`. Full design in
  `docs/superpowers/specs/2026-05-05-submission-assets-design.md`.

## Build commands

```bash
# arm64 (Mac dev)
docker buildx build --platform linux/arm64 \
  -f NewtonDockerfile -t newtonschool/newton-judge0:0.66 --load .

# amd64 (EC2 / prod)
docker buildx build --platform linux/amd64 \
  -f NewtonDockerfile -t newtonschool/newton-judge0:0.66 --load .
```

A full build takes ~15-20 min (most of it is OpenSSL 1.1 + Ruby 2.7.8
from source; the rest is bundle install).

## Dev workflow

Build the image first (see Build commands above; re-run only when
`Gemfile` or `NewtonDockerfile` changes). Then bring up the stack —
`docker-compose.dev.yml` includes nginx and resque-web images that are
old and may not start on current Docker Desktop, so skip those:

```bash
# Essentials only (skip nginx + resque-web + pgbouncer)
docker compose -f docker-compose.dev.yml up -d judge0 db redis redis-sidecar

# Start workers in the judge0 container (separate exec session)
docker compose -f docker-compose.dev.yml exec -d --privileged judge0 \
  bash -c 'source /api/scripts/load-config; cd /api && rake resque:workers QUEUE=*'

# Hit the API
curl http://localhost:2358/languages | jq

# Tear down (drops volumes)
docker compose -f docker-compose.dev.yml down -v
```

The host repo bind-mounts at `/api` inside the container, so editing
Ruby/Rails code is live (no rebuild needed for code-only changes; only
binaries — Ruby version, gems via `bundle install`, etc. — need a rebuild).

## End-to-end smoke test

```bash
JUDGE0_URL=http://localhost:2358 ./bin/newton-smoke-test
```

Submits a hello-world for every active language id. Expected (post-0.67
with Phase 3 asset capture; three Verilog cases — testbench-in-stdin,
empty-stdin self-contained, and wave.vcd asset):
**24 PASS / 0 FAIL / 0 SKIP** on amd64; **22 PASS / 0 FAIL / 2 SKIP** on
arm64 (NASM and FreeBASIC are amd64-only upstream).

Rspec tests in `spec/` are mostly upstream — Newton has not added
comprehensive specs. Don't rely on `bundle exec rspec` for end-to-end
validation; use `bin/newton-smoke-test`.

## judge0.conf knobs

Newton overrides on top of upstream defaults. Comments inline
in `judge0.conf` explain each. Summary:

| Setting | Default | Newton | Why |
|---|---|---|---|
| `ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT` | false | `${OVERRIDE_PER_PROCESS_TIME:-true}` → flipped to `false` by `docker-entrypoint.sh` when cgroup-v2 setup succeeds, so `IsolateJob` adds `--cg` and isolate uses `cpu.stat` / `memory.max` (RSS) instead of `RLIMIT_CPU` / `RLIMIT_AS` |
| `ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT` | false | same — flipped at runtime, gives RSS-based memory limits required for DSA per-question caps to be meaningful for JVM/Node/Python ML |
| `MEMORY_LIMIT` | 128 MB | **8 GiB** | JVM 21 + Node 22 + numpy each pre-reserve >1 GiB |
| `MAX_MEMORY_LIMIT` | 512 MB | **16 GiB** | per-submission memory_limit cap |
| `MAX_PROCESSES_AND_OR_THREADS` | 60 | **2048** | JVM/Node thread pools |
| `MAX_MAX_PROCESSES_AND_OR_THREADS` | 120 | **4096** | compile-time max |
| `MAX_FILE_SIZE` | 1 MB | **1 GiB** | Go 1.23 binaries + Java class+jar bundles can exceed 1 MB |
| `MAX_MAX_FILE_SIZE` | 4 MB | **2 GiB** | per-submission max |
| `MAX_MAX_ASSET_SIZE` | – (new in 0.67) | **20480** (20 KB) | Phase 3 asset cap; clamps any per-language `max_size` |

## Common pitfalls

1. **Compose env vars are overridden by `judge0.conf`.** `scripts/load-config`
   does `set -o allexport; source $CONFIG_FILE` which clobbers anything you
   pass via `docker-compose environment:`. Edit `judge0.conf` for sandbox
   tuning, not compose env.
2. **isolate `--cg` mode normally requires `isolate-cg-keeper` (systemd
   service) to populate `/run/isolate/cgroup`** — not available in
   non-systemd containers. `docker-entrypoint.sh` substitutes for it: at
   startup it lays out `/sys/fs/cgroup/{api.scope,isolate.slice}`, enables
   `subtree_control`, and writes `/run/isolate/cgroup` pointing at
   `isolate.slice`. The "no internal process constraint" is sidestepped
   by moving Rails/Resque into `api.scope` first. If that setup fails
   (cgroup v1 host, non-privileged container), the entrypoint falls back
   silently to rlimit mode.
3. **isolate command in `app/jobs/isolate_job.rb` doesn't expose `-O`
   (open files).** R and Go submissions hit RLIMIT_NOFILE. Adding it
   would mean editing IsolateJob and adding a `MAX_OPEN_FILES` knob to
   `judge0.conf` — a future PR.
4. **`gem 'rails', '~> 5.0'` is intentional.** Bumping to Rails 6/7
   forces a Ruby 3+ migration; we deliberately decoupled student-facing
   Ruby (3.3.6 in compilers image) from app-runtime Ruby (2.7.8) so the
   Rails upgrade can be its own project.
5. **bookworm's `/etc/apt/trusted.gpg.d/*.asc` is occasionally unparsable
   by gpgv** in some Docker Desktop / buildkit environments — `apt-get
   update` fails with "At least one invalid signature was encountered".
   `NewtonDockerfile` has a conditional `[trusted=yes]` fallback that
   activates only when this happens (silent on EC2 builds where apt
   verification works fine). The TLS layer to deb.debian.org still
   authenticates the mirror.
6. **`ennexa/resque-web:latest` ships an obsolete v1 manifest** that
   modern Docker rejects. Don't include it when bringing up the dev
   stack. The Resque jobs themselves run fine without the web UI.
7. **db/languages/active.rb path conventions matter.** Paths must point
   to what the compilers image actually ships. Rebuilding compilers
   without rebuilding judge0 (or vice versa) and forgetting to bump
   the FROM tag in `NewtonDockerfile` means submissions fail with "no
   such file or directory" mid-execution.

## Image is published as

- Docker Hub: `newtonschool/newton-judge0`
- Current tag: **`0.67`** — adds Phase 3 submission-assets capture
  (Verilog 3005 declares `wave.vcd`; framework is language-agnostic).
  Smoke target 24/0/0 on amd64.
- Production runs from ECR (`405612465938.dkr.ecr.ap-south-1.amazonaws.com/judge0:0.56`),
  pre-modernisation. Deploys are **single-image** (no docker-compose); the deployed
  `newton-judge0:<tag>` connects to managed Postgres + managed Redis from the environment.
- **Before bumping prod to 0.67:** prod nodes still run Amazon Linux 2 (cgroup v1).
  Flip the karpenter NodeClass to AL2023 first — otherwise `docker-entrypoint.sh`'s
  cgroup-v2 setup falls back silently to rlimit mode and you lose RSS-based limits.
- See `git log` for the 0.53 → 0.67 chronology if you need to bisect a regression.
