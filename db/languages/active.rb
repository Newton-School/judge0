@languages ||= []
@languages +=
[
  # 0.28: Plain Text restored (was archived in 0.59 trim). Needs no
  # toolchain — just `cat` of the submitted source file.
  {
    id: 43,
    name: "Plain Text",
    is_archived: false,
    source_file: "text.txt",
    run_cmd: "/bin/cat text.txt"
  },
  {
    id: 45,
    name: "Assembly (NASM 2.16.03)",
    is_archived: false,
    source_file: "main.asm",
    compile_cmd: "/usr/local/nasm-2.16.03/bin/nasmld -f elf64 %s main.asm",
    run_cmd: "./a.out"
  },
  {
    id: 46,
    name: "Bash (5.2.37)",
    is_archived: false,
    source_file: "script.sh",
    run_cmd: "/usr/local/bash-5.2.37/bin/bash script.sh"
  },
  {
    id: 47,
    name: "Basic (FBC 1.10.1)",
    is_archived: false,
    source_file: "main.bas",
    compile_cmd: "/usr/local/fbc-1.10.1/bin/fbc %s main.bas",
    run_cmd: "./main"
  },
  # 0.28: GCC 14.2.0 was removed from the compilers image (no production
  # submissions ever targeted ids 3003/3004); GCC 9.5.0 is now the sole
  # C/C++ toolchain. Lenient flags retained so legacy student code that
  # would have promoted to errors on GCC 14 keeps compiling on 9.5.
  {
    id: 50,
    name: "C (GCC 9.5.0)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 54,
    name: "C++ (GCC 9.5.0)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  # GOMAXPROCS=2: Go's runtime auto-detects CPUs from /proc/cpuinfo (host),
  # not cgroup CPU shares. Under isolate cgroup-mode, CPU time is summed
  # across all threads (cpu.stat aggregate), so an unconstrained Go runtime
  # spawns one OS thread per host vCPU and aggregate init CPU easily trips
  # the -t cpu-time-limit even for hello-world. Pinning to 2 keeps DSA
  # semantics single-thread-ish while leaving headroom for runtime/GC.
  {
    id: 60,
    name: "Go (1.23.4)",
    is_archived: false,
    source_file: "main.go",
    compile_cmd: "GOCACHE=/tmp/.cache/go-build /usr/local/go-1.23.4/bin/go build %s main.go",
    run_cmd: "GOMAXPROCS=2 ./main"
  },
  {
    id: 62,
    name: "Java (OpenJDK 21)",
    is_archived: false,
    source_file: "Main.java",
    compile_cmd: "/usr/local/openjdk-21/bin/javac %s Main.java",
    run_cmd: "/usr/local/openjdk-21/bin/java Main"
  },
  {
    id: 71,
    name: "Python (3.13.1)",
    is_archived: false,
    source_file: "script.py",
    run_cmd: "/usr/local/python-3.13.1/bin/python3 script.py"
  },
  {
    id: 72,
    name: "Ruby (3.3.6)",
    is_archived: false,
    source_file: "script.rb",
    run_cmd: "/usr/local/ruby-3.3.6/bin/ruby script.rb"
  },
  {
    id: 73,
    name: "Rust (1.83.0)",
    is_archived: false,
    source_file: "main.rs",
    compile_cmd: "/usr/local/rust-1.83.0/bin/rustc %s main.rs",
    run_cmd: "./main"
  },
  {
    id: 74,
    name: "TypeScript (5.7.2)",
    is_archived: false,
    source_file: "script.ts",
    compile_cmd: "/usr/local/node-22.11.0/bin/tsc %s script.ts",
    run_cmd: "/usr/local/node-22.11.0/bin/node script.js"
  },
  # 0.28: Kotlin restored (was archived in 0.59 trim). `kotlinc Main.kt`
  # produces MainKt.class (Kotlin's top-level-fun-to-class mangling); the
  # `kotlin` wrapper script handles classpath setup including the stdlib
  # jar and execs java internally.
  #
  # Compile-step JVM tuning: kotlinc bootstrap with the default G1GC +
  # uncapped metaspace blows past 500 MB on a hello-world compile and
  # gets OOM-killed by isolate's compile cgroup (which is hardcoded to
  # Config::MAX_MEMORY_LIMIT in app/jobs/isolate_job.rb, not the
  # per-submission memory_limit). The -J flags below keep total JVM
  # footprint under ~480 MB so it fits in the 500 MB cap. UseSerialGC is
  # not optional — G1's native bookkeeping is what tips the balance.
  {
    id: 78,
    name: "Kotlin (2.3.21)",
    is_archived: false,
    source_file: "Main.kt",
    compile_cmd: "/usr/local/kotlin-2.3.21/bin/kotlinc -J-Xmx384m -J-XX:MaxMetaspaceSize=80m -J-XX:ReservedCodeCacheSize=32m -J-XX:+UseSerialGC %s Main.kt",
    run_cmd: "/usr/local/kotlin-2.3.21/bin/kotlin MainKt"
  },
  {
    id: 80,
    name: "R (4.5.2)",
    is_archived: false,
    source_file: "script.r",
    run_cmd: "/usr/local/r-4.5.2/bin/Rscript script.r"
  },
  # 0.28: Scala 3 restored (was archived in 0.59 trim). Scala 3.5+ replaced
  # the legacy `scala` runner with a scala-cli launcher that expects
  # sources, not classnames, so we run via `java` directly with the Scala
  # stdlib jars on the classpath (matches bin/newton-test in compilers).
  {
    id: 81,
    name: "Scala 3 (3.8.3)",
    is_archived: false,
    source_file: "Main.scala",
    compile_cmd: "/usr/local/scala-3.8.3/bin/scalac %s Main.scala",
    run_cmd: "/usr/local/bin/java -cp \".:/usr/local/scala-3.8.3/lib/*\" Main"
  },
  {
    id: 82,
    name: "SQL (SQLite 3.47.0)",
    is_archived: false,
    source_file: "script.sql",
    run_cmd: "/bin/cat script.sql | /usr/local/sqlite-autoconf-3470000/bin/sqlite3 db.sqlite"
  },
  {
    id: 1999,
    name: "JavaScript (Node.js 22.11.0)",
    is_archived: false,
    source_file: "script.js",
    run_cmd: "NODE_PATH='/usr/local/node-22.11.0/lib/node_modules' /usr/local/node-22.11.0/bin/node script.js"
  },
  {
    id: 2000,
    name: "Python (3.12.7) for ML",
    is_archived: false,
    source_file: "script.py",
    run_cmd: "/usr/local/python-3.12.7/bin/python3 script.py"
  },
  {
    id: 3000,
    name: "HDL (Nand2Tetris)",
    is_archived: false,
    source_file: "main.hdl",
    run_cmd: "nand2tetris run main.hdl"
  },
  {
    id: 3001,
    name: "MIPS (Mars 4.5)",
    is_archived: false,
    source_file: "main.s",
    run_cmd: "/usr/local/bin/java -Djava.util.logging.config.file=/usr/local/mars/logging.properties -jar /usr/local/mars/mars.jar nc main.s"
  },
  {
    id: 3002,
    name: "Jack",
    is_archived: false,
    source_file: "Main.jack",
    run_cmd: "nand2tetris run Main.jack"
  },
  # Verilog (Icarus 13.0): student submits the DUT module(s) as source_code;
  # instructor-supplied testbench arrives via stdin. compile_cmd parse-checks
  # the DUT alone with `iverilog -tnull` so pure DUT syntax errors land in
  # the Compile Error bucket. run_cmd captures stdin to tb.v, full-elaborates
  # main.v + tb.v (no -s flag — iverilog auto-detects the testbench module
  # as top-level), runs vvp, and forwards vvp's stdout verbatim. Problem
  # authors must capture expected_output by running their testbench and
  # including whatever vvp prints — including the volatile
  # `tb.v:N: $finish called at T (1s)` epilogue. To suppress that epilogue,
  # use `$finish(0);` instead of `$finish;` in the testbench.
  # See docs/superpowers/specs/2026-05-02-iverilog-integration-design.md.
  {
    id: 3005,
    name: "Verilog (Icarus 13.0)",
    is_archived: false,
    source_file: "main.v",
    compile_cmd: "/usr/local/iverilog-13.0/bin/iverilog -g2012 -tnull %s main.v",
    run_cmd: "/bin/cat > tb.v && /usr/local/iverilog-13.0/bin/iverilog -g2012 -o sim.vvp main.v tb.v && /usr/local/iverilog-13.0/bin/vvp sim.vvp",
    # Phase 3 asset: capture .vcd waveforms produced by testbenches that
    # call $dumpfile/$dumpvars. Author opt-in is implicit (testbench
    # without $dumpfile produces no .vcd, regex matches nothing, no row).
    # 20 KB cap targets DSA-scale designs; authors needing larger dumps
    # must scope their $dumpvars (e.g. $dumpvars(1, testbench.dut)).
    # See docs/superpowers/specs/2026-05-05-submission-assets-design.md.
    assets: [
      { name: "wave.vcd", identification: '\.vcd$', max_size: 20480 }
    ]
  },
  # C# lanes restored on top of the cgroup-v2-capable compiler image.
  # We keep them as new ids instead of reusing historical ids because
  # those old ids were repurposed/archived during earlier trim cycles.
  {
    id: 3006,
    name: "C# (Mono 6.12.0.122)",
    is_archived: false,
    source_file: "Main.cs",
    compile_cmd: "mcs %s Main.cs",
    run_cmd: "mono Main.exe"
  },
  {
    id: 3007,
    name: "C# (.NET 8.0.420)",
    is_archived: false,
    source_file: "Main.cs",
    compile_cmd: "REF_DIR=$(echo /usr/local/dotnet-sdk/packs/Microsoft.NETCore.App.Ref/8.0.*/ref/net8.0) && RUNTIME_VERSION=$(dotnet --list-runtimes | awk '/Microsoft.NETCore.App 8\\./ {print $2; exit}') && printf '%%s\\n' '{ \"runtimeOptions\": { \"tfm\": \"net8.0\", \"framework\": { \"name\": \"Microsoft.NETCore.App\", \"version\": \"'\"$RUNTIME_VERSION\"'\" } } }' > Main.runtimeconfig.json && REFS=$(printf -- '-r:%%s ' \"$REF_DIR\"/*.dll) && DOTNET_ROOT=/usr/local/dotnet-sdk DOTNET_MULTILEVEL_LOOKUP=0 DOTNET_NOLOGO=1 dotnet /usr/local/dotnet-sdk/sdk/8.0.420/Roslyn/bincore/csc.dll -nologo -target:exe -out:Main.dll %s $REFS Main.cs",
    run_cmd: "DOTNET_ROOT=/usr/local/dotnet-sdk DOTNET_MULTILEVEL_LOOKUP=0 DOTNET_NOLOGO=1 dotnet exec --runtimeconfig Main.runtimeconfig.json Main.dll"
  },
  {
    id: 3008,
    name: "C# (.NET 10.0.202)",
    is_archived: false,
    source_file: "Main.cs",
    compile_cmd: "REF_DIR=$(echo /usr/local/dotnet-sdk/packs/Microsoft.NETCore.App.Ref/10.0.*/ref/net10.0) && RUNTIME_VERSION=$(dotnet --list-runtimes | awk '/Microsoft.NETCore.App 10\\./ {print $2; exit}') && printf '%%s\\n' '{ \"runtimeOptions\": { \"tfm\": \"net10.0\", \"framework\": { \"name\": \"Microsoft.NETCore.App\", \"version\": \"'\"$RUNTIME_VERSION\"'\" } } }' > Main.runtimeconfig.json && REFS=$(printf -- '-r:%%s ' \"$REF_DIR\"/*.dll) && DOTNET_ROOT=/usr/local/dotnet-sdk DOTNET_MULTILEVEL_LOOKUP=0 DOTNET_NOLOGO=1 dotnet /usr/local/dotnet-sdk/sdk/10.0.202/Roslyn/bincore/csc.dll -nologo -target:exe -out:Main.dll %s $REFS Main.cs",
    run_cmd: "DOTNET_ROOT=/usr/local/dotnet-sdk DOTNET_MULTILEVEL_LOOKUP=0 DOTNET_NOLOGO=1 dotnet exec --runtimeconfig Main.runtimeconfig.json Main.dll"
  }
]
