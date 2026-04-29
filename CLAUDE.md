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
| Compiler base | `newtonschool/judge0-newton-compiler:0.27` | what we layer on |
| Sandbox | `isolate` v2.0 (cgroup v2 capable, currently rlimit mode) | from compilers image |

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
│   ├── newton-smoke-test            # 51-language end-to-end smoke test
│   └── agricius                     # release tarball generator (rare use)
├── db/
│   ├── languages/active.rb          # canonical language id → command map
│   ├── languages/archived.rb        # historical/dropped languages
│   ├── seeds.rb                     # loads active.rb + archived.rb into DB
│   └── migrate/                     # rails migrations (don't add new ones lightly)
├── app/jobs/isolate_job.rb          # the sandbox runner — most complex Ruby in the repo
├── app/controllers/submissions_controller.rb
├── cron/{clear_cache,telemetry}     # baked-in cron entries
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

## Per-language tuning conventions (set during 0.26 modernisation)

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
- **GCC id 50 (C) / 54 (C++)** alias to `/usr/local/gcc-9.5.0/...` —
  the legacy compiler kept alongside GCC 14 for back-compat with old
  student code. New submissions should use **id 1001 (C / GCC 14.2.0)**
  or **id 1002 (C++ / GCC 14.2.0)**.

## Build commands

```bash
# arm64 (Mac dev)
docker buildx build --platform linux/arm64 \
  -f NewtonDockerfile -t newtonschool/newton-judge0:0.60 --load .

# amd64 (EC2 / prod)
docker buildx build --platform linux/amd64 \
  -f NewtonDockerfile -t newtonschool/newton-judge0:0.60 --load .
```

A full build takes ~15-20 min (most of it is OpenSSL 1.1 + Ruby 2.7.8
from source; the rest is bundle install).

## Dev workflow

`docker-compose.dev.yml` brings up the full stack. nginx and resque-web
images are old and may not start on current Docker Desktop, so:

```bash
# Build the app image first (once, then re-run only when Gemfile/Dockerfile changes)
docker buildx build --platform linux/arm64 \
  -f NewtonDockerfile -t newtonschool/newton-judge0:0.60 --load .

# Bring up only the essentials (skip nginx + resque-web + pgbouncer)
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

Submits a hello-world for every active language id. Should report ~37
PASS / 8 known-tuning FAIL / 6 SKIP (intentional skips). Failures are
documented inline in `bin/newton-smoke-test` and in the PR that added it.

## judge0.conf knobs (set during 0.26 modernisation)

These are Newton overrides on top of upstream defaults. Comments inline
in `judge0.conf` explain each. Summary:

| Setting | Default | Newton | Why |
|---|---|---|---|
| `ENABLE_PER_PROCESS_AND_THREAD_TIME_LIMIT` | false | **true** | so isolate runs without `--cg` (no systemd cgroup delegation needed) |
| `ENABLE_PER_PROCESS_AND_THREAD_MEMORY_LIMIT` | false | **true** | same |
| `MEMORY_LIMIT` | 128 MB | **8 GiB** | JVM 21 + Node 22 + numpy each pre-reserve >1 GiB |
| `MAX_MEMORY_LIMIT` | 512 MB | **16 GiB** | per-submission memory_limit cap |
| `MAX_PROCESSES_AND_OR_THREADS` | 60 | **2048** | JVM/Node thread pools |
| `MAX_MAX_PROCESSES_AND_OR_THREADS` | 120 | **4096** | compile-time max |
| `MAX_FILE_SIZE` | 1 MB | **1 GiB** | Go 1.23 binaries + Java class+jar bundles can exceed 1 MB |
| `MAX_MAX_FILE_SIZE` | 4 MB | **2 GiB** | per-submission max |

## Common pitfalls (encountered while building 0.26 + Phase 2 — don't repeat)

1. **Compose env vars are overridden by `judge0.conf`.** `scripts/load-config`
   does `set -o allexport; source $CONFIG_FILE` which clobbers anything you
   pass via `docker-compose environment:`. Edit `judge0.conf` for sandbox
   tuning, not compose env.
2. **isolate `--cg` mode requires `/run/isolate/cgroup`** which only exists
   if `isolate-cg-keeper` (a systemd service) is running. In a non-systemd
   container that fails with "Cannot open /run/isolate/cgroup". We rely on
   per-process rlimits via `ENABLE_PER_PROCESS_*=true` (see above) so this
   doesn't bite us.
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
- Pre-modernisation staging tag: `0.53` (compiler base 0.25)
- Phase-2 modernisation tag: `0.58` (compiler base 0.26) — superseded
- Phase-3 trim tag: `0.59` (compiler base 0.27, 25 low-usage langs archived) — superseded
- Phase-4 cgroup-mode tag: `0.60` (isolate v2 cgroup-v2 enforcement, RSS-based memory limits) — current
- Production currently runs from ECR (`405612465938.dkr.ecr.ap-south-1.amazonaws.com/judge0:0.56`),
  unrelated to Docker Hub tags. Modernisation will roll prod after staging soak.

## Production deploy model

The user explicitly chose **single-image deployment** for prod (no
docker-compose). The deployed `newton-judge0:<tag>` connects to managed
Postgres + managed Redis from the environment. `docker-compose.dev.yml`
is dev-only convenience.

## Working notes

- Rspec tests in `spec/` exist but are mostly upstream — Newton has not
  added comprehensive specs. Don't rely on `bundle exec rspec` for
  end-to-end validation; use `bin/newton-smoke-test` instead.
- `cron/clear_cache` and `cron/telemetry` are installed via crontab
  during image build. They expect `/api/tmp/environment` to exist
  (created by `scripts/load-config`).
- Migrations are append-only; the latest is from 2023-03-09. Don't
  modify old migrations.
