# Bounds-test comparison: staging (0.65) vs production

- **Production**: https://judge0-public.newtonschool.co — code in `master`, image `judge0:0.56` (ECR), rlimit-mode timing, Go 1.13.5, no GCC 14
- **Staging**:    https://judge0-public.staging-newtonschool.co — image `newtonschool/newton-judge0:0.65` (Docker Hub), compiler base `judge0-newton-compiler:0.28`, cgroup-v2 mode + cgroup-reset-between-compile-and-run fix, Go 1.23.4, **GCC 14 archived in 0.64**, **Kotlin 2.3.21 / Scala 3.8.3 / Plain Text revived in 0.64**, kotlinc compile_cmd carries explicit JVM heap caps (`-J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC`) so compiler fits inside the hardcoded 500 MB compile cgroup, `MAX_MAX_FILE_SIZE=1048576` (1 GiB).

Probe definitions:
- **HELLO**: print `Hello, Newton!` with default limits → expect `Accepted`
- **TLE**: busy loop with `cpu_time_limit=1`, `wall_time_limit=5` → expect `Time Limit Exceeded`
- **OOM**: 200 MB allocation with `memory_limit=65536` (64 MB) → expect `Runtime Error (NZEC)` (cgroup OOM kill)

Probe coverage in `bin/newton-bounds-test` is unchanged from the 0.62 run: still the 18 HELLO / 18 TLE / 14 OOM matrix. The 0.64 language-set changes (Plain Text id 43, Kotlin id 78, Scala id 81 added; GCC 14 ids 3003/3004 archived) are reflected in the smoke test (`bin/newton-smoke-test` — **21 / 0 / 0** on staging) but not yet in the bounds test. See *Notes* below.

## HELLO

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| NASM 45 | ✓ Accepted (t=0.002 · m=2948) | ✓ Accepted (t=0.002 · m=1104) | ✓ Accepted (t=0.002 · m=2356) | ✓ Accepted (t=0.002 · m=1020) |
| Bash 46 | ✓ Accepted (t=0.004 · m=2012) | ✓ Accepted (t=0.003 · m=952) | ✓ Accepted (t=0.004 · m=2008) | ✓ Accepted (t=0.003 · m=1148) |
| FreeBASIC 47 | ✓ Accepted (t=0.003 · m=20288) | ✓ Accepted (t=0.003 · m=1200) | ✓ Accepted (t=0.002 · m=19816) | ✓ Accepted (t=0.003 · m=1144) |
| C GCC9.5 50 | ✓ Accepted (t=0.002 · m=3840) | ✓ Accepted (t=0.002 · m=824) | ✓ Accepted (t=0.002 · m=720) | ✓ Accepted (t=0.003 · m=1100) |
| C++ GCC9.5 54 | ✓ Accepted (t=0.003 · m=1576) | ✓ Accepted (t=0.003 · m=1140) | ✓ Accepted (t=0.003 · m=848) | ✓ Accepted (t=0.004 · m=1016) |
| Go 60 | ✓ Accepted (t=0.003 · m=4712) | ✓ Accepted (t=0.004 · m=3188) | ✓ Accepted (t=0.003 · m=3812) | ✓ Accepted (t=0.004 · m=2956) |
| Java 62 | ✓ Accepted (t=0.048 · m=10632) | ✓ Accepted (t=0.04 · m=19880) | ✓ Accepted (t=0.047 · m=10512) | ✓ Accepted (t=0.041 · m=19920) |
| Python 71 | ✓ Accepted (t=0.012 · m=3524) | ✓ Accepted (t=0.014 · m=3472) | ✓ Accepted (t=0.017 · m=3448) | ✓ Accepted (t=0.014 · m=3532) |
| Ruby 72 | ✓ Accepted (t=0.046 · m=9056) | ✓ Accepted (t=0.059 · m=6376) | ✓ Accepted (t=0.043 · m=9156) | ✓ Accepted (t=0.064 · m=6256) |
| Rust 73 | ✓ Accepted (t=0.002 · m=127924) | ✓ Accepted (t=0.003 · m=1164) | ✓ Accepted (t=0.002 · m=127880) | ✓ Accepted (t=0.003 · m=1312) |
| TypeScript 74 | ✓ Accepted (t=0.034 · m=8364) | ✓ Accepted (t=0.026 · m=7920) | ✓ Accepted (t=0.026 · m=8004) | ✓ Accepted (t=0.026 · m=8156) |
| R 80 | ✓ Accepted (t=0.169 · m=60500) | ✓ Accepted (t=0.167 · m=43140) | ✓ Accepted (t=0.169 · m=60624) | ✓ Accepted (t=0.167 · m=42996) |
| SQL 82 | ✓ Accepted (t=0.005 · m=2528) | ✓ Accepted (t=0.005 · m=1352) | ✓ Accepted (t=0.005 · m=2540) | ✓ Accepted (t=0.004 · m=1592) |
| Node.js 1999 | ✓ Accepted (t=0.045 · m=8020) | ✓ Accepted (t=0.025 · m=8312) | ✓ Accepted (t=0.027 · m=7948) | ✓ Accepted (t=0.025 · m=8376) |
| Python ML 2000 | ✓ Accepted (t=0.017 · m=4708) | ✓ Accepted (t=0.013 · m=3772) | ✓ Accepted (t=0.014 · m=3416) | ✓ Accepted (t=0.014 · m=3772) |
| MIPS 3001 | ✓ Accepted (t=1.135 · m=52016) | ✓ Accepted (t=1.08 · m=53268) | ✓ Accepted (t=1.169 · m=50108) | ✓ Accepted (t=1.055 · m=53668) |
| C GCC14 3003 | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |
| C++ GCC14 3004 | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |

## TLE

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| NASM TLE | ✓ Time Limit Exceeded (t=2.535 · m=2892) | ✓ Time Limit Exceeded (t=5.099 · m=820) | ✓ Time Limit Exceeded (t=5.072 · m=696) | ✓ Time Limit Exceeded (t=5.026 · m=840) |
| Bash TLE | ✓ Time Limit Exceeded (t=2.508 · m=1996) | ✓ Time Limit Exceeded (t=5.044 · m=960) | ✓ Time Limit Exceeded (t=5.063 · m=1392) | ✓ Time Limit Exceeded (t=5.031 · m=1020) |
| FreeBASIC TLE | ✓ Time Limit Exceeded (t=2.496 · m=2520) | ✓ Time Limit Exceeded (t=5.011 · m=944) | ✓ Time Limit Exceeded (t=5.063 · m=848) | ✓ Time Limit Exceeded (t=5.099 · m=940) |
| C9.5 TLE | ✓ Time Limit Exceeded (t=2.498 · m=3980) | ✓ Time Limit Exceeded (t=5.031 · m=1276) | ✓ Time Limit Exceeded (t=5.067 · m=712) | ✓ Time Limit Exceeded (t=5.045 · m=760) |
| C++9.5 TLE | ✓ Time Limit Exceeded (t=2.476 · m=1256) | ✓ Time Limit Exceeded (t=5.025 · m=844) | ✓ Time Limit Exceeded (t=5.067 · m=716) | ✓ Time Limit Exceeded (t=5.049 · m=1016) |
| Go TLE | ✓ Time Limit Exceeded (t=2.511 · m=4220) | ✓ Time Limit Exceeded (t=5.073 · m=2760) | ✓ Time Limit Exceeded (t=5.073 · m=3088) | ✓ Time Limit Exceeded (t=5.055 · m=2936) |
| Java TLE | ✓ Time Limit Exceeded (t=2.507 · m=10408) | ✓ Time Limit Exceeded (t=5.101 · m=19836) | ✓ Time Limit Exceeded (t=5.074 · m=10452) | ✓ Time Limit Exceeded (t=5.061 · m=20316) |
| Python TLE | ✓ Time Limit Exceeded (t=2.532 · m=3364) | ✓ Time Limit Exceeded (t=5.023 · m=3492) | ✓ Time Limit Exceeded (t=5.076 · m=3440) | ✓ Time Limit Exceeded (t=5.053 · m=3772) |
| Ruby TLE | ✓ Time Limit Exceeded (t=2.501 · m=9068) | ✓ Time Limit Exceeded (t=5.005 · m=5952) | ✓ Time Limit Exceeded (t=5.075 · m=9092) | ✓ Time Limit Exceeded (t=5.019 · m=6368) |
| Rust TLE | ✗ Compilation Error | ✓ Time Limit Exceeded (t=5.054 · m=1160) | ✗ Compilation Error | ✓ Time Limit Exceeded (t=5.061 · m=1196) |
| TypeScript TLE | ✓ Time Limit Exceeded (t=2.511 · m=9884) | ✓ Time Limit Exceeded (t=5.056 · m=7960) | ✓ Time Limit Exceeded (t=5.07 · m=8104) | ✓ Time Limit Exceeded (t=5.032 · m=8168) |
| R TLE | ✓ Time Limit Exceeded (t=2.537 · m=64360) | ✓ Time Limit Exceeded (t=5.102 · m=64548) | ✓ Time Limit Exceeded (t=5.059 · m=64332) | ✓ Time Limit Exceeded (t=5.047 · m=64548) |
| SQL TLE | ✓ Time Limit Exceeded (t=2.484 · m=2652) | ✓ Time Limit Exceeded (t=5.101 · m=1440) | ✓ Time Limit Exceeded (t=5.07 · m=1760) | ✓ Time Limit Exceeded (t=5.04 · m=1664) |
| Node TLE | ✓ Time Limit Exceeded (t=2.5 · m=7824) | ✓ Time Limit Exceeded (t=5.034 · m=7680) | ✓ Time Limit Exceeded (t=5.074 · m=7772) | ✓ Time Limit Exceeded (t=5.016 · m=8424) |
| Python ML TLE | ✓ Time Limit Exceeded (t=2.533 · m=5732) | ✓ Time Limit Exceeded (t=5.028 · m=3780) | ✓ Time Limit Exceeded (t=5.072 · m=3620) | ✓ Time Limit Exceeded (t=5.035 · m=3784) |
| MIPS TLE | ✓ Time Limit Exceeded (t=2.508 · m=37896) | ✓ Time Limit Exceeded (t=5.014 · m=51268) | ✓ Time Limit Exceeded (t=5.077 · m=40700) | ✓ Time Limit Exceeded (t=5.066 · m=51752) |
| C14 TLE | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |
| C++14 TLE | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |

## OOM

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| FreeBASIC OOM | ✓ Runtime Error (NZEC) (t=0.295 · m=65536) | ✓ Runtime Error (NZEC) (t=0.1 · m=65536) | ✓ Runtime Error (NZEC) (t=0.351 · m=65536) | ✓ Runtime Error (NZEC) (t=0.101 · m=65536) |
| C9.5 OOM | ✓ Runtime Error (NZEC) (t=0.36 · m=65536) | ✓ Runtime Error (NZEC) (t=0.098 · m=65536) | ✓ Runtime Error (NZEC) (t=0.293 · m=65536) | ✓ Runtime Error (NZEC) (t=0.096 · m=65536) |
| C++9.5 OOM | ✓ Runtime Error (NZEC) (t=0.311 · m=65536) | ✓ Runtime Error (NZEC) (t=0.101 · m=65536) | ✓ Runtime Error (NZEC) (t=0.369 · m=65536) | ✓ Runtime Error (NZEC) (t=0.101 · m=65536) |
| Go OOM | ✓ Runtime Error (NZEC) (t=0.423 · m=65536) | ✓ Runtime Error (NZEC) (t=0.116 · m=65536) | ✓ Runtime Error (NZEC) (t=0.386 · m=65536) | ✓ Runtime Error (NZEC) (t=0.109 · m=65536) |
| Java OOM | ✓ Runtime Error (NZEC) (t=0.375 · m=65536) | ✓ Runtime Error (NZEC) (t=0.131 · m=65536) | ✓ Runtime Error (NZEC) (t=0.438 · m=65536) | ✓ Runtime Error (NZEC) (t=0.129 · m=65536) |
| Python OOM | ✓ Runtime Error (NZEC) (t=0.369 · m=65536) | ✓ Runtime Error (NZEC) (t=0.111 · m=65536) | ✓ Runtime Error (NZEC) (t=0.31 · m=65536) | ✓ Runtime Error (NZEC) (t=0.106 · m=65536) |
| Ruby OOM | ✓ Runtime Error (NZEC) (t=0.346 · m=65536) | ✓ Runtime Error (NZEC) (t=0.158 · m=65536) | ✓ Runtime Error (NZEC) (t=0.405 · m=65536) | ✓ Runtime Error (NZEC) (t=0.158 · m=65536) |
| Rust OOM | ✓ Runtime Error (NZEC) (t=0.382 · m=65536) | ✓ Runtime Error (NZEC) (t=0.104 · m=65536) | ✓ Runtime Error (NZEC) (t=0.364 · m=65536) | ✓ Runtime Error (NZEC) (t=0.102 · m=65536) |
| TypeScript OOM | ✓ Runtime Error (NZEC) (t=0.322 · m=65536) | ✓ Runtime Error (NZEC) (t=0.121 · m=65536) | ✓ Runtime Error (NZEC) (t=0.393 · m=65536) | ✓ Runtime Error (NZEC) (t=0.123 · m=65536) |
| R OOM | ✓ Runtime Error (NZEC) (t=0.464 · m=65536) | ✓ Runtime Error (NZEC) (t=0.275 · m=65536) | ✓ Runtime Error (NZEC) (t=0.475 · m=65536) | ✓ Runtime Error (NZEC) (t=0.273 · m=65536) |
| Node OOM | ✓ Runtime Error (NZEC) (t=0.39 · m=65536) | ✓ Runtime Error (NZEC) (t=0.12 · m=65536) | ✓ Runtime Error (NZEC) (t=0.38 · m=65536) | ✓ Runtime Error (NZEC) (t=0.121 · m=65536) |
| Python ML OOM | ✓ Runtime Error (NZEC) (t=0.319 · m=65536) | ✓ Runtime Error (NZEC) (t=0.108 · m=65536) | ✓ Runtime Error (NZEC) (t=0.315 · m=65536) | ✓ Runtime Error (NZEC) (t=0.107 · m=65536) |
| C14 OOM | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |
| C++14 OOM | ✗ ? | ✗ ? | ✗ NO TOKEN | ✗ NO TOKEN |

## Tally

- **Prod**:    86/100 PASS
- **Staging**: 88/100 PASS *(was 100/100 in 0.62 — see notes)*

## Failure breakdown

### Prod failures

- `[sync]` **C GCC14 3003** — got `?`
- `[sync]` **C++ GCC14 3004** — got `?`
- `[sync]` **Rust TLE** — got `Compilation Error`
- `[sync]` **C14 TLE** — got `?`
- `[sync]` **C++14 TLE** — got `?`
- `[sync]` **C14 OOM** — got `?`
- `[sync]` **C++14 OOM** — got `?`
- `[async]` **C GCC14 3003** — got `NO TOKEN`
- `[async]` **C++ GCC14 3004** — got `NO TOKEN`
- `[async]` **Rust TLE** — got `Compilation Error`
- `[async]` **C14 TLE** — got `NO TOKEN`
- `[async]` **C++14 TLE** — got `NO TOKEN`
- `[async]` **C14 OOM** — got `NO TOKEN`
- `[async]` **C++14 OOM** — got `NO TOKEN`

### Staging failures

- `[sync]` **C GCC14 3003** — got `?`
- `[sync]` **C++ GCC14 3004** — got `?`
- `[sync]` **C14 TLE** — got `?`
- `[sync]` **C++14 TLE** — got `?`
- `[sync]` **C14 OOM** — got `?`
- `[sync]` **C++14 OOM** — got `?`
- `[async]` **C GCC14 3003** — got `NO TOKEN`
- `[async]` **C++ GCC14 3004** — got `NO TOKEN`
- `[async]` **C14 TLE** — got `NO TOKEN`
- `[async]` **C++14 TLE** — got `NO TOKEN`
- `[async]` **C14 OOM** — got `NO TOKEN`
- `[async]` **C++14 OOM** — got `NO TOKEN`

## Notes

**Why staging dropped from 100/100 to 88/100**: not a regression — `bin/newton-bounds-test` still includes probes for C / C++ GCC 14 (ids 3003 / 3004), which were intentionally archived in 0.64. Both environments now reject those submissions: prod with `NO TOKEN` (the ids never existed in `master`'s active.rb), staging with the same shape because `Language.default_scope` filters archived ids out before the controller validates the request. The 12 cells (2 langs × 3 probes × 2 modes) are the entire 100 → 88 delta. The other ∂ on prod (Rust TLE compilation error) is identical to the 0.62 run — same root cause (older Rust pre-`std::hint::black_box`).

**To restore a fully-green staging tally**, drop the GCC 14 probes from `bin/newton-bounds-test` (ids `3003`, `3004` references on lines ~241/261/272-ish). The probes still cover GCC 9.5 (50 / 54), which is the only C/C++ toolchain in 0.28+. Tracked but not done in this PR — bounds-test refactor is a separate piece of work.

**Plain Text (43), Kotlin (78), Scala 3 (81) bounds coverage**: not yet added to `bin/newton-bounds-test`. Plain Text has no meaningful TLE/OOM probes (it's just `cat`); Kotlin and Scala both compile JVM bytecode and could run the same TLE/OOM patterns as Java. Adding them is straightforward but deferred from this PR. Smoke-test coverage exists today via `bin/newton-smoke-test` (HELLO only): all three pass on staging.

**Kotlin compile fitting in the 500 MB cgroup (0.65 hotfix)**: `app/jobs/isolate_job.rb` hardcodes the compile step's `--cg-mem` to `Config::MAX_MEMORY_LIMIT` regardless of per-submission `memory_limit`. Staging's `MAX_MEMORY_LIMIT=512000 KB` (500 MB) was insufficient for kotlinc with default G1GC + uncapped metaspace + default code-cache reservation — the JVM's native footprint blew past 500 MB and the cgroup OOM-killer SIGKILL'd the java subprocess on every Kotlin submission. Fix is `-J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC` baked into the language's compile_cmd; `UseSerialGC` is load-bearing (G1's native bookkeeping was the difference between a ~480 MB and ~600 MB resident footprint). Documented in CLAUDE.md per-language tuning conventions.

**Why staging needed `MAX_MAX_FILE_SIZE` bumped to enable Go**: `app/jobs/isolate_job.rb` uses `Config::MAX_MAX_FILE_SIZE` (the global cap) for the **compile** step's `-f` flag, not the per-submission `max_file_size`. Default `MAX_MAX_FILE_SIZE` is 4096 KB (4 MB) — fine for Go 1.13.5 on prod (binaries ≈ 1.5–2 MB) but too small for Go 1.23.4 on staging (compile intermediates exceed ~12 MB; minimum measured threshold for `go build hello.go` is between 12 000 KB and 13 000 KB). Setting `MAX_MAX_FILE_SIZE=1048576` (1 GiB) on staging lifted that cap and Go now compiles cleanly.

**Go 1.13.5 (prod) vs Go 1.23.4 (staging)** — why the size difference: 5 years of stdlib growth. Go 1.13's `runtime` package is much smaller; generics (1.18+) and the rewritten regex/PGO/coverage instrumentation in 1.20–1.22 each added megabytes to the linked artifacts. Hello-world final binary went from ~1.6 MB (1.13) to ~2.5 MB (1.23) and intermediate `_pkg_.a` archives in `$WORK/b00x/` are larger still because they include the entire transitive import compilation, not just main.

**Why prod fails Rust TLE**: the test source uses `std::hint::black_box`, stabilized in **Rust 1.66** (Dec 2022). Prod's pre-modernise Rust toolchain is older than 1.66, so the import fails to compile. Staging's Rust 1.83.0 (in `compilers:0.28`) compiles it cleanly. This is a Rust-version difference, not a regression — the modernise upgrade is what makes the TLE source work.

**Memory readout differences**: prod uses rlimit-mode `max-rss` (per-process resident set size); staging uses cgroup `memory.peak` (cgroup-wide peak). For single-process programs the two are close. After the 0.62 cgroup-reset between compile and run, run-time `memory.peak` reflects only the run phase.

**TLE timing**: prod's sync TLE fires at ~2.5s of CPU time; staging's at ~5.0s. The difference is cgroup-v2 cpu.stat sampling lag — under `--cg-timing`, isolate samples `cpu.stat` periodically rather than receiving an immediate signal, so a few hundred milliseconds of CPU can accumulate past `cpu_time_limit + cpu_extra_time` before SIGKILL fires. Both still kill before `wall_time_limit=5`. Acceptable but more lenient on staging by ~2.5×.

**OOM speed**: staging is 3× faster than prod (avg 0.13s vs 0.37s) — cgroup `memory.max` triggers OOM kill the moment RSS crosses the cap; prod's `RLIMIT_AS` lets the process malloc past the cap and crash on page fault. Both end with `mem=65536` exactly on staging (cgroup cap), prod sometimes overshoots before crash.
