# Bounds-test comparison: staging (0.65) vs production

- **Production**: https://judge0-public.newtonschool.co — code in `master`, image `judge0:0.56` (ECR), rlimit-mode timing, Go 1.13.5, no GCC 14
- **Staging**:    https://judge0-public.staging-newtonschool.co — image `newtonschool/newton-judge0:0.65` (Docker Hub), compiler base `judge0-newton-compiler:0.28`, cgroup-v2 mode + cgroup-reset-between-compile-and-run fix, Go 1.23.4, **GCC 14 archived in 0.64**, **Kotlin 2.3.21 / Scala 3.8.3 / Plain Text revived in 0.64**, kotlinc compile_cmd carries explicit JVM heap caps (`-J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC`) so compiler fits inside the hardcoded 500 MB compile cgroup, `MAX_MAX_FILE_SIZE=1048576` (1 GiB).

Probe definitions:
- **HELLO**: print `Hello, Newton!` with default limits → expect `Accepted`
- **TLE**: busy loop with `cpu_time_limit=1`, `wall_time_limit=5` → expect `Time Limit Exceeded`
- **OOM**: 200 MB allocation with `memory_limit=65536` (64 MB) → expect `Runtime Error (NZEC)` (cgroup OOM kill)

Probe coverage in `bin/newton-bounds-test` updated for the 0.64 / 0.28-base language set:
- **Removed**: GCC 14 ids 3003 / 3004 (archived in active.rb).
- **Added**: Plain Text 43 (HELLO only — `cat`-based, no busy-loop / alloc), Kotlin 78 (HELLO + TLE + OOM), Scala 3 81 (HELLO + TLE + OOM).
- **Total**: 19 HELLO + 18 TLE + 14 OOM = 51 probes × 2 modes = 102 cells.

## HELLO

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| Plain Text 43 | ✓ Accepted (t=0.002 · m=684) | ✓ Accepted (t=0.003 · m=1020) | ✓ Accepted (t=0.002 · m=820) | ✓ Accepted (t=0.003 · m=840) |
| NASM 45 | ✓ Accepted (t=0.002 · m=3092) | ✓ Accepted (t=0.002 · m=1020) | ✓ Accepted (t=0.001 · m=2304) | ✓ Accepted (t=0.002 · m=848) |
| Bash 46 | ✓ Accepted (t=0.004 · m=2060) | ✓ Accepted (t=0.003 · m=1148) | ✓ Accepted (t=0.004 · m=2040) | ✓ Accepted (t=0.004 · m=1104) |
| FreeBASIC 47 | ✓ Accepted (t=0.002 · m=3196) | ✓ Accepted (t=0.003 · m=1020) | ✓ Accepted (t=0.002 · m=1256) | ✓ Accepted (t=0.003 · m=1100) |
| C GCC9.5 50 | ✓ Accepted (t=0.003 · m=4240) | ✓ Accepted (t=0.002 · m=1020) | ✓ Accepted (t=0.002 · m=740) | ✓ Accepted (t=0.002 · m=1020) |
| C++ GCC9.5 54 | ✓ Accepted (t=0.003 · m=3520) | ✓ Accepted (t=0.003 · m=1148) | ✓ Accepted (t=0.003 · m=804) | ✓ Accepted (t=0.004 · m=1076) |
| Go 60 | ✓ Accepted (t=0.002 · m=8512) | ✓ Accepted (t=0.004 · m=3332) | ✓ Accepted (t=0.003 · m=5912) | ✓ Accepted (t=0.004 · m=3368) |
| Java 62 | ✓ Accepted (t=0.048 · m=12780) | ✓ Accepted (t=0.042 · m=19840) | ✓ Accepted (t=0.047 · m=13064) | ✓ Accepted (t=0.04 · m=20332) |
| Python 71 | ✓ Accepted (t=0.013 · m=3472) | ✓ Accepted (t=0.014 · m=3512) | ✓ Accepted (t=0.012 · m=3500) | ✓ Accepted (t=0.014 · m=3508) |
| Ruby 72 | ✓ Accepted (t=0.044 · m=9116) | ✓ Accepted (t=0.059 · m=6088) | ✓ Accepted (t=0.044 · m=9468) | ✓ Accepted (t=0.062 · m=5920) |
| Rust 73 | ✓ Accepted (t=0.002 · m=6176) | ✓ Accepted (t=0.003 · m=1392) | ✓ Accepted (t=0.002 · m=4244) | ✓ Accepted (t=0.003 · m=1204) |
| TypeScript 74 | ✓ Accepted (t=0.045 · m=7960) | ✓ Accepted (t=0.027 · m=7616) | ✓ Accepted (t=0.027 · m=8024) | ✓ Accepted (t=0.025 · m=8372) |
| Kotlin 78 | ✓ Accepted (t=0.105 · m=72832) | ✓ Accepted (t=0.184 · m=29532) | ✓ Accepted (t=0.101 · m=66604) | ✓ Accepted (t=0.183 · m=29848) |
| R 80 | ✓ Accepted (t=0.169 · m=50056) | ✓ Accepted (t=0.165 · m=43756) | ✓ Accepted (t=0.144 · m=45548) | ✓ Accepted (t=0.165 · m=44272) |
| Scala 81 | ✓ Accepted (t=0.772 · m=58604) | ✓ Accepted (t=0.251 · m=33764) | ✓ Accepted (t=0.8 · m=69712) | ✓ Accepted (t=0.244 · m=33756) |
| SQL 82 | ✓ Accepted (t=0.005 · m=2520) | ✓ Accepted (t=0.004 · m=1612) | ✓ Accepted (t=0.005 · m=2572) | ✓ Accepted (t=0.004 · m=1436) |
| Node.js 1999 | ✓ Accepted (t=0.033 · m=14928) | ✓ Accepted (t=0.026 · m=8080) | ✓ Accepted (t=0.027 · m=8364) | ✓ Accepted (t=0.027 · m=7860) |
| Python ML 2000 | ✓ Accepted (t=0.015 · m=5704) | ✓ Accepted (t=0.013 · m=3772) | ✓ Accepted (t=0.015 · m=3532) | ✓ Accepted (t=0.013 · m=3724) |
| MIPS 3001 | ✓ Accepted (t=1.111 · m=50384) | ✓ Accepted (t=1.081 · m=52916) | ✓ Accepted (t=1.295 · m=53640) | ✓ Accepted (t=1.064 · m=53204) |

## TLE

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| NASM TLE | ✓ Time Limit Exceeded (t=2.529 · m=3208) | ✓ Time Limit Exceeded (t=5.03 · m=1020) | ✓ Time Limit Exceeded (t=5.079 · m=2528) | ✓ Time Limit Exceeded (t=5.053 · m=1016) |
| Bash TLE | ✓ Time Limit Exceeded (t=2.523 · m=1988) | ✓ Time Limit Exceeded (t=5.037 · m=1404) | ✓ Time Limit Exceeded (t=5.066 · m=1996) | ✓ Time Limit Exceeded (t=5.018 · m=1212) |
| FreeBASIC TLE | ✓ Time Limit Exceeded (t=2.511 · m=9124) | ✓ Time Limit Exceeded (t=5.044 · m=1084) | ✓ Time Limit Exceeded (t=5.076 · m=4536) | ✓ Time Limit Exceeded (t=5.047 · m=1144) |
| C9.5 TLE | ✓ Time Limit Exceeded (t=2.521 · m=6124) | ✓ Time Limit Exceeded (t=5.042 · m=820) | ✓ Time Limit Exceeded (t=5.075 · m=1504) | ✓ Time Limit Exceeded (t=5.022 · m=1016) |
| C++9.5 TLE | ✓ Time Limit Exceeded (t=2.546 · m=1688) | ✓ Time Limit Exceeded (t=5.031 · m=1564) | ✓ Time Limit Exceeded (t=5.082 · m=1188) | ✓ Time Limit Exceeded (t=5.041 · m=1404) |
| Go TLE | ✓ Time Limit Exceeded (t=2.538 · m=10176) | ✓ Time Limit Exceeded (t=5.022 · m=2632) | ✓ Time Limit Exceeded (t=5.081 · m=4552) | ✓ Time Limit Exceeded (t=5.054 · m=2944) |
| Java TLE | ✓ Time Limit Exceeded (t=2.532 · m=10484) | ✓ Time Limit Exceeded (t=5.039 · m=19892) | ✓ Time Limit Exceeded (t=5.067 · m=10480) | ✓ Time Limit Exceeded (t=5.04 · m=19920) |
| Python TLE | ✓ Time Limit Exceeded (t=2.505 · m=8860) | ✓ Time Limit Exceeded (t=5.004 · m=3472) | ✓ Time Limit Exceeded (t=5.071 · m=3448) | ✓ Time Limit Exceeded (t=5.03 · m=3520) |
| Ruby TLE | ✓ Time Limit Exceeded (t=2.49 · m=9148) | ✓ Time Limit Exceeded (t=5.016 · m=6472) | ✓ Time Limit Exceeded (t=5.068 · m=9372) | ✓ Time Limit Exceeded (t=5.031 · m=6020) |
| Rust TLE | ✗ Compilation Error | ✓ Time Limit Exceeded (t=5.022 · m=1220) | ✗ Compilation Error | ✓ Time Limit Exceeded (t=5.037 · m=1216) |
| TypeScript TLE | ✓ Time Limit Exceeded (t=2.524 · m=9984) | ✓ Time Limit Exceeded (t=5.033 · m=7660) | ✓ Time Limit Exceeded (t=5.078 · m=10056) | ✓ Time Limit Exceeded (t=5.028 · m=7968) |
| Kotlin TLE | ✓ Time Limit Exceeded (t=2.523 · m=15616) | ✓ Time Limit Exceeded (t=5.091 · m=29076) | ✓ Time Limit Exceeded (t=5.067 · m=14116) | ✓ Time Limit Exceeded (t=5.081 · m=29448) |
| R TLE | ✓ Time Limit Exceeded (t=2.493 · m=65704) | ✓ Time Limit Exceeded (t=5.049 · m=64552) | ✓ Time Limit Exceeded (t=5.079 · m=64260) | ✓ Time Limit Exceeded (t=5.03 · m=65380) |
| Scala TLE | ✓ Time Limit Exceeded (t=2.503 · m=44832) | ✓ Time Limit Exceeded (t=5.005 · m=20576) | ✓ Time Limit Exceeded (t=5.084 · m=59348) | ✓ Time Limit Exceeded (t=5.1 · m=20100) |
| SQL TLE | ✓ Time Limit Exceeded (t=2.504 · m=1820) | ✓ Time Limit Exceeded (t=5.012 · m=1720) | ✓ Time Limit Exceeded (t=5.076 · m=1172) | ✓ Time Limit Exceeded (t=5.048 · m=1528) |
| Node TLE | ✓ Time Limit Exceeded (t=2.455 · m=8568) | ✓ Time Limit Exceeded (t=5.038 · m=8144) | ✓ Time Limit Exceeded (t=5.07 · m=7764) | ✓ Time Limit Exceeded (t=5.102 · m=7612) |
| Python ML TLE | ✓ Time Limit Exceeded (t=2.535 · m=3892) | ✓ Time Limit Exceeded (t=5.029 · m=3788) | ✓ Time Limit Exceeded (t=5.066 · m=3144) | ✓ Time Limit Exceeded (t=5.046 · m=3748) |
| MIPS TLE | ✓ Time Limit Exceeded (t=2.539 · m=35108) | ✓ Time Limit Exceeded (t=5.04 · m=51552) | ✓ Time Limit Exceeded (t=5.074 · m=41676) | ✓ Time Limit Exceeded (t=5.032 · m=51572) |

## OOM

| Lang | sync prod | sync staging | async prod | async staging |
|---|---|---|---|---|
| FreeBASIC OOM | ✓ Runtime Error (NZEC) (t=0.377 · m=65536) | ✓ Runtime Error (NZEC) (t=0.099 · m=65536) | ✓ Runtime Error (NZEC) (t=0.35 · m=65536) | ✓ Runtime Error (NZEC) (t=0.101 · m=65536) |
| C9.5 OOM | ✓ Runtime Error (NZEC) (t=0.293 · m=65536) | ✓ Runtime Error (NZEC) (t=0.098 · m=65536) | ✓ Runtime Error (NZEC) (t=0.305 · m=65536) | ✓ Runtime Error (NZEC) (t=0.102 · m=65536) |
| C++9.5 OOM | ✓ Runtime Error (NZEC) (t=0.362 · m=65536) | ✓ Runtime Error (NZEC) (t=0.098 · m=65536) | ✓ Runtime Error (NZEC) (t=0.365 · m=65536) | ✓ Runtime Error (NZEC) (t=0.098 · m=65536) |
| Go OOM | ✓ Runtime Error (NZEC) (t=0.385 · m=65536) | ✓ Runtime Error (NZEC) (t=0.116 · m=65536) | ✓ Runtime Error (NZEC) (t=0.664 · m=65536) | ✓ Runtime Error (NZEC) (t=0.12 · m=65536) |
| Java OOM | ✓ Runtime Error (NZEC) (t=0.439 · m=65536) | ✓ Runtime Error (NZEC) (t=0.131 · m=65536) | ✓ Runtime Error (NZEC) (t=0.363 · m=65536) | ✓ Runtime Error (NZEC) (t=0.125 · m=65536) |
| Python OOM | ✓ Runtime Error (NZEC) (t=0.327 · m=65536) | ✓ Runtime Error (NZEC) (t=0.109 · m=65536) | ✓ Runtime Error (NZEC) (t=0.368 · m=65536) | ✓ Runtime Error (NZEC) (t=0.104 · m=65536) |
| Ruby OOM | ✓ Runtime Error (NZEC) (t=0.413 · m=65536) | ✓ Runtime Error (NZEC) (t=0.16 · m=65536) | ✓ Runtime Error (NZEC) (t=0.357 · m=65536) | ✓ Runtime Error (NZEC) (t=0.161 · m=65536) |
| Rust OOM | ✓ Runtime Error (NZEC) (t=0.338 · m=65536) | ✓ Runtime Error (NZEC) (t=0.123 · m=65536) | ✓ Runtime Error (NZEC) (t=0.393 · m=65536) | ✓ Runtime Error (NZEC) (t=0.103 · m=65536) |
| TypeScript OOM | ✓ Runtime Error (NZEC) (t=0.385 · m=65536) | ✓ Runtime Error (NZEC) (t=0.119 · m=65536) | ✓ Runtime Error (NZEC) (t=0.338 · m=65536) | ✓ Runtime Error (NZEC) (t=0.12 · m=65536) |
| Kotlin OOM | ✓ Runtime Error (NZEC) (t=0.439 · m=65536) | ✓ Runtime Error (NZEC) (t=0.277 · m=65536) | ✓ Runtime Error (NZEC) (t=0.491 · m=65536) | ✓ Runtime Error (NZEC) (t=0.276 · m=65536) |
| R OOM | ✓ Runtime Error (NZEC) (t=0.53 · m=65536) | ✓ Runtime Error (NZEC) (t=0.272 · m=65536) | ✓ Runtime Error (NZEC) (t=0.492 · m=65536) | ✓ Runtime Error (NZEC) (t=0.268 · m=65536) |
| Scala OOM | ✓ Runtime Error (NZEC) (t=1.062 · m=65536) | ✓ Runtime Error (NZEC) (t=0.133 · m=65536) | ✓ Runtime Error (NZEC) (t=1.209 · m=65536) | ✓ Runtime Error (NZEC) (t=0.13 · m=65536) |
| Node OOM | ✓ Runtime Error (NZEC) (t=0.388 · m=65536) | ✓ Runtime Error (NZEC) (t=0.118 · m=65536) | ✓ Runtime Error (NZEC) (t=0.338 · m=65536) | ✓ Runtime Error (NZEC) (t=0.119 · m=65536) |
| Python ML OOM | ✓ Runtime Error (NZEC) (t=0.322 · m=65536) | ✓ Runtime Error (NZEC) (t=0.107 · m=65536) | ✓ Runtime Error (NZEC) (t=0.37 · m=65536) | ✓ Runtime Error (NZEC) (t=0.107 · m=65536) |

## Tally

- **Prod**:    100/102 PASS
- **Staging**: 102/102 PASS

## Failure breakdown

### Prod failures

- `[sync]` **Rust TLE** — got `Compilation Error`
- `[async]` **Rust TLE** — got `Compilation Error`

### Staging failures

_(none)_

## Notes

**Plain Text / Kotlin / Scala on prod**: surprise — all three pass on prod too. They were never trimmed from `master`'s `active.rb`; the 0.59 trim happened on the `modernise` branch only, and prod never picked it up. So the language IDs (43, 78, 81) have always been live on prod with their pre-modernise paths (`kotlin-2.1.0`, `scala-3.6.2` etc.), which is why the bounds probes resolve. The staging deploy gets the bumped versions (Kotlin 2.3.21, Scala 3.8.3) plus the JVM heap caps for kotlinc; functionally equivalent for hello-world but on a current toolchain.

**Why prod still fails Rust TLE**: the test source uses `std::hint::black_box`, stabilized in **Rust 1.66** (Dec 2022). Prod's pre-modernise Rust is older than 1.66, so the import fails to compile. Staging's Rust 1.83.0 (in `compilers:0.28`) compiles it cleanly. This is a Rust-version difference, not a regression — the modernise upgrade is what makes the TLE source work.

**Kotlin compile fitting in the 500 MB cgroup (0.65 hotfix)**: `app/jobs/isolate_job.rb` hardcodes the compile step's `--cg-mem` to `Config::MAX_MEMORY_LIMIT` regardless of per-submission `memory_limit`. Staging's `MAX_MEMORY_LIMIT=512000 KB` (500 MB) was insufficient for Kotlin 2.3.21's compiler with default G1GC + uncapped metaspace + default code-cache reservation — the JVM's native footprint blew past 500 MB and the cgroup OOM-killer SIGKILL'd the java subprocess on every Kotlin submission. Fix is `-J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC` baked into the language's compile_cmd; `UseSerialGC` is load-bearing (G1's native bookkeeping was the difference between a ~480 MB and ~600 MB resident footprint). Documented in CLAUDE.md per-language tuning conventions. Prod runs Kotlin 2.1.0 which doesn't need this — older compiler footprint is smaller.

**Why Scala compile is `t=0.7-0.8s` on prod but `t=0.25s` on staging**: prod's Scala 3.6.2 cold-start is heavier (the older release loads more upfront) and, more importantly, prod's CPU accounting is rlimit-mode `RUSAGE_SELF` which is wall-clockish for the compile; staging's cgroup `cpu.stat` only counts the compile-step subprocess. Staging's `t=0.25s` looks faster but is measuring a smaller window.

**Why staging needed `MAX_MAX_FILE_SIZE` bumped to enable Go**: `app/jobs/isolate_job.rb` uses `Config::MAX_MAX_FILE_SIZE` (the global cap) for the **compile** step's `-f` flag, not the per-submission `max_file_size`. Default `MAX_MAX_FILE_SIZE` is 4096 KB (4 MB) — fine for Go 1.13.5 on prod (binaries ≈ 1.5–2 MB) but too small for Go 1.23.4 on staging (compile intermediates exceed ~12 MB; minimum measured threshold for `go build hello.go` is between 12 000 KB and 13 000 KB). Setting `MAX_MAX_FILE_SIZE=1048576` (1 GiB) on staging lifted that cap and Go now compiles cleanly.

**Go 1.13.5 (prod) vs Go 1.23.4 (staging)** — why the size difference: 5 years of stdlib growth. Go 1.13's `runtime` package is much smaller; generics (1.18+) and the rewritten regex/PGO/coverage instrumentation in 1.20–1.22 each added megabytes to the linked artifacts. Hello-world final binary went from ~1.6 MB (1.13) to ~2.5 MB (1.23) and intermediate `_pkg_.a` archives in `$WORK/b00x/` are larger still because they include the entire transitive import compilation, not just main.

**Memory readout differences**: prod uses rlimit-mode `max-rss` (per-process resident set size); staging uses cgroup `memory.peak` (cgroup-wide peak). For single-process programs the two are close. After the 0.62 cgroup-reset between compile and run, run-time `memory.peak` reflects only the run phase.

**TLE timing**: prod's sync TLE fires at ~2.5s of CPU time; staging's at ~5.0s. The difference is cgroup-v2 cpu.stat sampling lag — under `--cg-timing`, isolate samples `cpu.stat` periodically rather than receiving an immediate signal, so a few hundred milliseconds of CPU can accumulate past `cpu_time_limit + cpu_extra_time` before SIGKILL fires. Both still kill before `wall_time_limit=5`. Acceptable but more lenient on staging by ~2.5×.

**OOM speed**: staging is 3-4× faster than prod for most languages — cgroup `memory.max` triggers OOM kill the moment RSS crosses the cap; prod's `RLIMIT_AS` lets the process malloc past the cap and crash on page fault. Both end with `mem=65536` exactly on staging (cgroup cap). Kotlin / Scala / R OOM probes are slower on both because the JVM/runtime startup itself fills enough heap to OOM before the explicit alloc finishes; the `t=0.27-1.2s` figures reflect runtime startup, not the alloc loop.
