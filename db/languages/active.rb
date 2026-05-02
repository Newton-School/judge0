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
  }
]
