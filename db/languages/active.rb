@languages ||= []
@languages +=
[
  {
    id: 43,
    name: "Plain Text",
    is_archived: false,
    source_file: "text.txt",
    run_cmd: "/bin/cat text.txt"
  },
  {
    id: 44,
    name: "Executable",
    is_archived: false,
    source_file: "a.out",
    run_cmd: "/bin/chmod +x a.out && ./a.out"
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
  # IDs 48/49/50 retained for backward-compat with legacy submissions; all
  # three alias to GCC 9.5.0 (the frozen legacy compiler kept in the
  # compilers image alongside GCC 14). New submissions should prefer
  # id 1001 (C / GCC 14.2.0). Lenient flags soften GCC-9-vs-GCC-14
  # warning-promoted-to-error breakage where a student's old code is
  # eventually re-run on the modern compiler.
  {
    id: 48,
    name: "C (GCC 7.4.0)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 49,
    name: "C (GCC 8.3.0)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 50,
    name: "C (GCC 9.5.0)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  # id 51 (C# .NET 8) moved to archived.rb until isolate cgroup-mode lands.
  # See archived.rb for context.
  {
    id: 52,
    name: "C++ (GCC 7.4.0)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  {
    id: 53,
    name: "C++ (GCC 8.3.0)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  {
    id: 54,
    name: "C++ (GCC 9.5.0)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  {
    id: 55,
    name: "Common Lisp (SBCL 2.4.10)",
    is_archived: false,
    source_file: "script.lisp",
    run_cmd: "SBCL_HOME=/usr/local/sbcl-2.4.10/lib/sbcl /usr/local/sbcl-2.4.10/bin/sbcl --script script.lisp"
  },
  {
    id: 56,
    name: "D (DMD 2.110.0)",
    is_archived: false,
    source_file: "main.d",
    compile_cmd: "/usr/local/d-2.110.0/linux/bin64/dmd %s main.d",
    run_cmd: "./main"
  },
  {
    id: 57,
    name: "Elixir (1.17.3)",
    is_archived: false,
    source_file: "script.exs",
    run_cmd: "/usr/local/elixir-1.17.3/bin/elixir script.exs"
  },
  {
    id: 58,
    name: "Erlang (OTP 27.1.2)",
    is_archived: false,
    source_file: "main.erl",
    run_cmd: "/bin/sed -i '1s/^/\\n/' main.erl && /usr/local/erlang-27.1.2/bin/escript main.erl"
  },
  {
    id: 59,
    name: "Fortran (GFortran 14.2.0)",
    is_archived: false,
    source_file: "main.f90",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/gfortran -fallow-argument-mismatch %s main.f90",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-14.2.0/lib64 ./a.out"
  },
  {
    id: 60,
    name: "Go (1.23.4)",
    is_archived: false,
    source_file: "main.go",
    compile_cmd: "GOCACHE=/tmp/.cache/go-build /usr/local/go-1.23.4/bin/go build %s main.go",
    run_cmd: "./main"
  },
  {
    id: 61,
    name: "Haskell (GHC 9.10.1)",
    is_archived: false,
    source_file: "main.hs",
    compile_cmd: "/usr/local/ghc-9.10.1/bin/ghc -dynamic %s main.hs",
    run_cmd: "./main"
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
    id: 64,
    name: "Lua (5.4.7)",
    is_archived: false,
    source_file: "script.lua",
    compile_cmd: "/usr/local/lua-5.4.7/bin/luac %s script.lua",
    run_cmd: "/usr/local/lua-5.4.7/bin/lua ./luac.out"
  },
  {
    id: 65,
    name: "OCaml (5.2.0)",
    is_archived: false,
    source_file: "main.ml",
    compile_cmd: "/usr/local/ocaml-5.2.0/bin/ocamlc %s main.ml",
    run_cmd: "./a.out"
  },
  {
    id: 66,
    name: "Octave (8.4.0)",
    is_archived: false,
    source_file: "script.m",
    run_cmd: "/usr/local/octave/bin/octave-cli -q --no-gui --no-history script.m"
  },
  {
    id: 67,
    name: "Pascal (FPC 3.2.2)",
    is_archived: false,
    source_file: "main.pas",
    compile_cmd: "/usr/local/fpc-3.2.2/bin/fpc %s main.pas",
    run_cmd: "./main"
  },
  {
    id: 68,
    name: "PHP (8.4.1)",
    is_archived: false,
    source_file: "script.php",
    run_cmd: "/usr/local/php-8.4.1/bin/php script.php"
  },
  {
    id: 69,
    name: "Prolog (GNU Prolog 1.5.0)",
    is_archived: false,
    source_file: "main.pro",
    compile_cmd: "PATH=\"/usr/local/gprolog-1.5.0/bin:$PATH\" /usr/local/gprolog-1.5.0/bin/gplc --no-top-level %s main.pro",
    run_cmd: "./main"
  },
  # id 70 (Python 2.7.17) moved to archived.rb (Python 2 EOL since 2020)
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
  {
    id: 75,
    name: "C (Clang 19)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/bin/clang-19 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 76,
    name: "C++ (Clang 19)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/bin/clang++-19 %s main.cpp",
    run_cmd: "./a.out"
  },
  {
    id: 77,
    name: "COBOL (GnuCOBOL 3.2)",
    is_archived: false,
    source_file: "main.cob",
    compile_cmd: "/usr/local/gnucobol-3.2/bin/cobc -free -x %s main.cob",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gnucobol-3.2/lib ./main"
  },
  # JVM-based languages: JAVA_TOOL_OPTIONS=-XX:ActiveProcessorCount=1 is
  # injected globally by IsolateJob so the JVM right-sizes thread pools
  # to the sandbox. Older revisions of this file had per-language
  # JAVA_OPTS prefixes; those have been removed because some launchers
  # (kotlin, scala) silently ignore JAVA_OPTS, while JAVA_TOOL_OPTIONS
  # is read by the JVM itself.
  {
    id: 78,
    name: "Kotlin (2.1.0)",
    is_archived: false,
    source_file: "Main.kt",
    compile_cmd: "/usr/local/kotlin-2.1.0/bin/kotlinc %s Main.kt",
    run_cmd: "/usr/local/kotlin-2.1.0/bin/kotlin MainKt"
  },
  {
    id: 79,
    name: "Objective-C (Clang 19)",
    is_archived: false,
    source_file: "main.m",
    compile_cmd: "/usr/bin/clang-19 `gnustep-config --objc-flags | sed 's/-W[^ ]* //g'` `gnustep-config --base-libs | sed 's/-shared-libgcc//'` main.m %s",
    run_cmd: "./a.out"
  },
  {
    id: 80,
    name: "R (4.5.2)",
    is_archived: false,
    source_file: "script.r",
    run_cmd: "/usr/local/r-4.5.2/bin/Rscript script.r"
  },
  # Scala 3's `scala` launcher is scala-cli with subcommands (`scala run`,
  # `scala compile`, etc.) — `scala Main` is no longer valid. Run the
  # compiled class via the Java launcher with the Scala 3 runtime libs
  # on the classpath. Faster than scala-cli too.
  {
    id: 81,
    name: "Scala 3 (3.6.2)",
    is_archived: false,
    source_file: "Main.scala",
    compile_cmd: "/usr/local/scala-3.6.2/bin/scalac %s Main.scala",
    run_cmd: "/usr/local/bin/java -cp \".:/usr/local/scala-3.6.2/lib/*\" Main"
  },
  {
    id: 82,
    name: "SQL (SQLite 3.47.0)",
    is_archived: false,
    source_file: "script.sql",
    run_cmd: "/bin/cat script.sql | /usr/local/sqlite-autoconf-3470000/bin/sqlite3 db.sqlite"
  },
  {
    id: 83,
    name: "Swift (6.0.3)",
    is_archived: false,
    source_file: "Main.swift",
    compile_cmd: "/usr/local/swift-6.0.3/bin/swiftc %s Main.swift",
    run_cmd: "./Main"
  },
  # id 84 (Visual Basic.Net via vbnc/Mono) moved to archived.rb (Mono dropped)
  {
    id: 85,
    name: "Perl (5.36)",
    is_archived: false,
    source_file: "script.pl",
    run_cmd: "/usr/bin/perl script.pl"
  },
  # Clojure 1.12's clojure-tools jar does not have a Main-Class manifest
  # attribute (1.10.x did). Invoke clojure.main as the entry point on
  # the classpath instead of `java -jar`.
  {
    id: 86,
    name: "Clojure (1.12)",
    is_archived: false,
    source_file: "main.clj",
    run_cmd: "/usr/local/bin/java -cp /usr/local/clojure-1.12.0.1495/clojure.jar clojure.main main.clj"
  },
  # id 87 (F# .NET 8) moved to archived.rb until isolate cgroup-mode lands.
  # See archived.rb for context.
  {
    id: 88,
    name: "Groovy (4.0.24)",
    is_archived: false,
    source_file: "script.groovy",
    compile_cmd: "/usr/local/groovy-4.0.24/bin/groovyc %s script.groovy",
    run_cmd: "/usr/local/bin/java -cp \".:/usr/local/groovy-4.0.24/lib/*\" script"
  },
  {
    id: 89,
    name: "Multi-file program",
    is_archived: false,
  },
  # New IDs for current GCC 14 — same lenient flags so new student code is
  # tolerant of legacy idioms while new submissions get the modern compiler.
  {
    id: 1001,
    name: "C (GCC 14.2.0)",
    is_archived: false,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 1002,
    name: "C++ (GCC 14.2.0)",
    is_archived: false,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-14.2.0/lib64 ./a.out"
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
