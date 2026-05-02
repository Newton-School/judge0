@languages ||= []
@languages +=
[
  {
    id: 1,
    name: "Bash (4.4)",
    is_archived: true,
    source_file: "script.sh",
    run_cmd: "/usr/local/bash-4.4/bin/bash script.sh"
  },
  {
    id: 2,
    name: "Bash (4.0)",
    is_archived: true,
    source_file: "script.sh",
    run_cmd: "/usr/local/bash-4.0/bin/bash script.sh"
  },
  {
    id: 3,
    name: "Basic (fbc 1.05.0)",
    is_archived: true,
    source_file: "main.bas",
    compile_cmd: "/usr/local/fbc-1.05.0/bin/fbc %s main.bas",
    run_cmd: "./main"
  },
  {
    id: 4,
    name: "C (gcc 7.2.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-7.2.0/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 5,
    name: "C (gcc 6.4.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-6.4.0/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 6,
    name: "C (gcc 6.3.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-6.3.0/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 7,
    name: "C (gcc 5.4.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-5.4.0/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 8,
    name: "C (gcc 4.9.4)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-4.9.4/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 9,
    name: "C (gcc 4.8.5)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-4.8.5/bin/gcc %s main.c",
    run_cmd: "./a.out"
  },

  {
    id: 10,
    name: "C++ (g++ 7.2.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-7.2.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-7.2.0/lib64 ./a.out"
  },
  {
    id: 11,
    name: "C++ (g++ 6.4.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-6.4.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-6.4.0/lib64 ./a.out"
  },
  {
    id: 12,
    name: "C++ (g++ 6.3.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-6.3.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-6.3.0/lib64 ./a.out"
  },
  {
    id: 13,
    name: "C++ (g++ 5.4.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-5.4.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-5.4.0/lib64 ./a.out"
  },
  {
    id: 14,
    name: "C++ (g++ 4.9.4)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-4.9.4/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-4.9.4/lib64 ./a.out"
  },
  {
    id: 15,
    name: "C++ (g++ 4.8.5)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-4.8.5/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-4.8.5/lib64 ./a.out"
  },
  {
    id: 16,
    name: "C# (mono 5.4.0.167)",
    is_archived: true,
    source_file: "Main.cs",
    compile_cmd: "/usr/local/mono-5.4.0.167/bin/mcs %s Main.cs",
    run_cmd: "/usr/local/mono-5.4.0.167/bin/mono Main.exe"
  },
  {
    id: 17,
    name: "C# (mono 5.2.0.224)",
    is_archived: true,
    source_file: "Main.cs",
    compile_cmd: "/usr/local/mono-5.2.0.224/bin/mcs %s Main.cs",
    run_cmd: "/usr/local/mono-5.2.0.224/bin/mono Main.exe"
  },
  {
    id: 18,
    name: "Clojure (1.8.0)",
    is_archived: true,
    source_file: "main.clj",
    run_cmd: "/usr/bin/java -cp /usr/local/clojure-1.8.0/clojure-1.8.0.jar clojure.main main.clj"
  },
  {
    id: 19,
    name: "Crystal (0.23.1)",
    is_archived: true,
    source_file: "main.cr",
    compile_cmd: "/usr/local/crystal-0.23.1-3/bin/crystal build %s main.cr",
    run_cmd: "./main"
  },
  {
    id: 20,
    name: "Elixir (1.5.1)",
    is_archived: true,
    source_file: "main.exs",
    run_cmd: "/usr/local/elixir-1.5.1/bin/elixir main.exs"
  },
  {
    id: 21,
    name: "Erlang (OTP 20.0)",
    is_archived: true,
    source_file: "main.erl",
    run_cmd: "/bin/sed -i \"s/^/\\n/\" main.erl && /usr/local/erlang-20.0/bin/escript main.erl"
  },
  {
    id: 22,
    name: "Go (1.9)",
    is_archived: true,
    source_file: "main.go",
    compile_cmd: "/usr/local/go-1.9/bin/go build %s main.go",
    run_cmd: "./main"
  },
  {
    id: 23,
    name: "Haskell (ghc 8.2.1)",
    is_archived: true,
    source_file: "main.hs",
    compile_cmd: "/usr/local/ghc-8.2.1/bin/ghc %s main.hs",
    run_cmd: "./main"
  },
  {
    id: 24,
    name: "Haskell (ghc 8.0.2)",
    is_archived: true,
    source_file: "main.hs",
    compile_cmd: "/usr/local/ghc-8.0.2/bin/ghc %s main.hs",
    run_cmd: "./main"
  },
  {
    id: 25,
    name: "Insect (5.0.0)",
    is_archived: true,
    source_file: "main.ins",
    run_cmd: "/usr/local/insect-5.0.0/insect main.ins"
  },
  {
    id: 26,
    name: "Java (OpenJDK 9 with Eclipse OpenJ9)",
    is_archived: true,
    source_file: "Main.java",
    compile_cmd: "/usr/local/openjdk9-openj9/bin/javac %s Main.java",
    run_cmd: "/usr/local/openjdk9-openj9/bin/java Main"
  },
  {
    id: 27,
    name: "Java (OpenJDK 8)",
    is_archived: true,
    source_file: "Main.java",
    compile_cmd: "/usr/lib/jvm/java-8-openjdk-amd64/bin/javac %s Main.java",
    run_cmd: "/usr/lib/jvm/java-8-openjdk-amd64/bin/java Main",
  },
  {
    id: 28,
    name: "Java (OpenJDK 7)",
    is_archived: true,
    source_file: "Main.java",
    compile_cmd: "/usr/lib/jvm/java-7-openjdk-amd64/bin/javac %s Main.java",
    run_cmd: "/usr/lib/jvm/java-7-openjdk-amd64/bin/java Main",
  },
  {
    id: 29,
    name: "JavaScript (nodejs 8.5.0)",
    is_archived: true,
    source_file: "main.js",
    run_cmd: "/usr/local/node-8.5.0/bin/node main.js"
  },
  {
    id: 30,
    name: "JavaScript (nodejs 7.10.1)",
    is_archived: true,
    source_file: "main.js",
    run_cmd: "/usr/local/node-7.10.1/bin/node main.js"
  },
  {
    id: 31,
    name: "OCaml (4.05.0)",
    is_archived: true,
    source_file: "main.ml",
    compile_cmd: "/usr/local/ocaml-4.05.0/bin/ocamlc %s main.ml",
    run_cmd: "./a.out"
  },
  {
    id: 32,
    name: "Octave (4.2.0)",
    is_archived: true,
    source_file: "file.m",
    run_cmd: "/usr/local/octave-4.2.0/bin/octave-cli -q --no-gui --no-history file.m"
  },
  {
    id: 33,
    name: "Pascal (fpc 3.0.0)",
    is_archived: true,
    source_file: "main.pas",
    compile_cmd: "/usr/local/fpc-3.0.0/bin/fpc %s main.pas",
    run_cmd: "./main"
  },
  {
    id: 34,
    name: "Python (3.6.0)",
    is_archived: true,
    source_file: "main.py",
    run_cmd: "/usr/local/python-3.6.0/bin/python3 main.py"
  },
  {
    id: 35,
    name: "Python (3.5.3)",
    is_archived: true,
    source_file: "main.py",
    run_cmd: "/usr/local/python-3.5.3/bin/python3 main.py"
  },
  {
    id: 36,
    name: "Python (2.7.9)",
    is_archived: true,
    source_file: "main.py",
    run_cmd: "/usr/local/python-2.7.9/bin/python main.py"
  },
  {
    id: 37,
    name: "Python (2.6.9)",
    is_archived: true,
    source_file: "main.py",
    run_cmd: "/usr/local/python-2.6.9/bin/python main.py"
  },
  {
    id: 38,
    name: "Ruby (2.4.0)",
    is_archived: true,
    source_file: "main.rb",
    run_cmd: "/usr/local/ruby-2.4.0/bin/ruby main.rb"
  },
  {
    id: 39,
    name: "Ruby (2.3.3)",
    is_archived: true,
    source_file: "main.rb",
    run_cmd: "/usr/local/ruby-2.3.3/bin/ruby main.rb"
  },
  {
    id: 40,
    name: "Ruby (2.2.6)",
    is_archived: true,
    source_file: "main.rb",
    run_cmd: "/usr/local/ruby-2.2.6/bin/ruby main.rb"
  },
  {
    id: 41,
    name: "Ruby (2.1.9)",
    is_archived: true,
    source_file: "main.rb",
    run_cmd: "/usr/local/ruby-2.1.9/bin/ruby main.rb"
  },
  {
    id: 42,
    name: "Rust (1.20.0)",
    is_archived: true,
    source_file: "main.rs",
    compile_cmd: "/usr/local/rust-1.20.0/bin/rustc %s main.rs",
    run_cmd: "./main"
  },
  {
    id: 63,
    name: "JavaScript (Node.js 12.14.0)",
    is_archived: true,
    source_file: "script.js",
    run_cmd: "/usr/local/node-12.14.0/bin/node script.js"
  },
  # Archived in 0.26 (Phase 2): Python 2 reached end-of-life on 2020-01-01;
  # the modern compilers image no longer ships /usr/local/python-2.7.17.
  {
    id: 70,
    name: "Python (2.7.17)",
    is_archived: true,
    source_file: "script.py",
    run_cmd: "/usr/local/python-2.7.17/bin/python2 script.py"
  },
  # Archived in 0.57: ids 48 (C / GCC 7.4) and 49 (C / GCC 8.3) were aliases
  # for GCC 9.5.0 — keeping them as separate dropdown entries was misleading
  # since they all produced the same binary. Students who specifically need
  # GCC 9.5 should pick id 50; modern code should pick id 3003 (GCC 14).
  {
    id: 48,
    name: "C (GCC 7.4.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 49,
    name: "C (GCC 8.3.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  # Archived in 0.57: ids 52 (C++ / GCC 7.4) and 53 (C++ / GCC 8.3), same
  # reason as 48/49. Use id 54 (GCC 9.5) or id 3004 (GCC 14) instead.
  {
    id: 52,
    name: "C++ (GCC 7.4.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  {
    id: 53,
    name: "C++ (GCC 8.3.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-9.5.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-9.5.0/lib64 ./a.out"
  },
  # Archived in 0.26 (Phase 2): Mono dropped from compilers image, so the
  # vbnc-based VB.Net path is no longer available. .NET 8 vbc is not a
  # drop-in equivalent for the legacy student-submission flow.
  {
    id: 84,
    name: "Visual Basic.Net (vbnc 0.0.0.5943)",
    is_archived: true,
    source_file: "Main.vb",
    compile_cmd: "/usr/bin/vbnc %s Main.vb",
    run_cmd: "/usr/bin/mono Main.exe"
  },
  # Archived in 0.57: .NET 8 CoreCLR is incompatible with isolate's
  # rlimit-mode sandboxing — RLIMIT_AS breaks GC heap init and RLIMIT_FSIZE
  # trips SIGXFSZ on JIT writes. Kept archived because we're not pursuing
  # the cgroup-mode infrastructure that would be needed to host them.
  {
    id: 51,
    name: "C# (.NET 8)",
    is_archived: true,
    source_file: "Main.cs"
  },
  {
    id: 87,
    name: "F# (.NET 8)",
    is_archived: true,
    source_file: "script.fsx"
  },
  # Archived in 0.59 (compilers 0.27): aggressive trim driven by prod usage.
  # All 25 languages below had <100 playgrounds in prod (most had 0-10).
  # Compiler toolchains for each are no longer in newtonschool/judge0-newton-
  # compiler:0.27 — the run_cmd paths kept here are historical context for
  # any future revival. To revive: restore the install RUN to the compilers
  # Dockerfile and copy this entry back into active.rb with is_archived:false.
  #
  # 0.28 update: ids 43 (Plain Text), 78 (Kotlin), 81 (Scala 3) revived
  # for re-introduced course tracks — see active.rb.
  {
    id: 44,
    name: "Executable",
    is_archived: true,
    source_file: "a.out",
    run_cmd: "/bin/chmod +x a.out && ./a.out"
  },
  {
    id: 55,
    name: "Common Lisp (SBCL 2.4.10)",
    is_archived: true,
    source_file: "script.lisp",
    run_cmd: "SBCL_HOME=/usr/local/sbcl-2.4.10/lib/sbcl /usr/local/sbcl-2.4.10/bin/sbcl --script script.lisp"
  },
  {
    id: 56,
    name: "D (DMD 2.110.0)",
    is_archived: true,
    source_file: "main.d",
    compile_cmd: "/usr/local/d-2.110.0/linux/bin64/dmd %s main.d",
    run_cmd: "./main"
  },
  {
    id: 57,
    name: "Elixir (1.17.3)",
    is_archived: true,
    source_file: "script.exs",
    run_cmd: "/usr/local/elixir-1.17.3/bin/elixir script.exs"
  },
  {
    id: 58,
    name: "Erlang (OTP 27.1.2)",
    is_archived: true,
    source_file: "main.erl",
    run_cmd: "/bin/sed -i '1s/^/\\n/' main.erl && /usr/local/erlang-27.1.2/bin/escript main.erl"
  },
  {
    id: 59,
    name: "Fortran (GFortran 14.2.0)",
    is_archived: true,
    source_file: "main.f90",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/gfortran -fallow-argument-mismatch %s main.f90",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-14.2.0/lib64 ./a.out"
  },
  {
    id: 61,
    name: "Haskell (GHC 9.10.1)",
    is_archived: true,
    source_file: "main.hs",
    compile_cmd: "/usr/local/ghc-9.10.1/bin/ghc -dynamic %s main.hs",
    run_cmd: "./main"
  },
  {
    id: 64,
    name: "Lua (5.4.7)",
    is_archived: true,
    source_file: "script.lua",
    compile_cmd: "/usr/local/lua-5.4.7/bin/luac %s script.lua",
    run_cmd: "/usr/local/lua-5.4.7/bin/lua ./luac.out"
  },
  {
    id: 65,
    name: "OCaml (5.2.0)",
    is_archived: true,
    source_file: "main.ml",
    compile_cmd: "/usr/local/ocaml-5.2.0/bin/ocamlc %s main.ml",
    run_cmd: "./a.out"
  },
  {
    id: 66,
    name: "Octave (8.4.0)",
    is_archived: true,
    source_file: "script.m",
    run_cmd: "/usr/local/octave/bin/octave-cli -q --no-gui --no-history script.m"
  },
  {
    id: 67,
    name: "Pascal (FPC 3.2.2)",
    is_archived: true,
    source_file: "main.pas",
    compile_cmd: "/usr/local/fpc-3.2.2/bin/fpc %s main.pas",
    run_cmd: "./main"
  },
  {
    id: 68,
    name: "PHP (8.4.1)",
    is_archived: true,
    source_file: "script.php",
    run_cmd: "/usr/local/php-8.4.1/bin/php script.php"
  },
  {
    id: 69,
    name: "Prolog (GNU Prolog 1.5.0)",
    is_archived: true,
    source_file: "main.pro",
    compile_cmd: "PATH=\"/usr/local/gprolog-1.5.0/bin:$PATH\" /usr/local/gprolog-1.5.0/bin/gplc --no-top-level %s main.pro",
    run_cmd: "./main"
  },
  {
    id: 75,
    name: "C (Clang 19)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/bin/clang-19 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 76,
    name: "C++ (Clang 19)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/bin/clang++-19 %s main.cpp",
    run_cmd: "./a.out"
  },
  {
    id: 77,
    name: "COBOL (GnuCOBOL 3.2)",
    is_archived: true,
    source_file: "main.cob",
    compile_cmd: "/usr/local/gnucobol-3.2/bin/cobc -free -x %s main.cob",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gnucobol-3.2/lib ./main"
  },
  {
    id: 79,
    name: "Objective-C (Clang 19)",
    is_archived: true,
    source_file: "main.m",
    compile_cmd: "/usr/bin/clang-19 `gnustep-config --objc-flags | sed 's/-W[^ ]* //g'` `gnustep-config --base-libs | sed 's/-shared-libgcc//'` main.m %s",
    run_cmd: "./a.out"
  },
  {
    id: 83,
    name: "Swift (6.0.3)",
    is_archived: true,
    source_file: "Main.swift",
    compile_cmd: "/usr/local/swift-6.0.3/bin/swiftc %s Main.swift",
    run_cmd: "./Main"
  },
  {
    id: 85,
    name: "Perl (5.36)",
    is_archived: true,
    source_file: "script.pl",
    run_cmd: "/usr/bin/perl script.pl"
  },
  {
    id: 86,
    name: "Clojure (1.12)",
    is_archived: true,
    source_file: "main.clj",
    run_cmd: "/usr/local/bin/java -cp /usr/local/clojure-1.12.0.1495/clojure.jar clojure.main main.clj"
  },
  {
    id: 88,
    name: "Groovy (4.0.24)",
    is_archived: true,
    source_file: "script.groovy",
    compile_cmd: "/usr/local/groovy-4.0.24/bin/groovyc %s script.groovy",
    run_cmd: "/usr/local/bin/java -cp \".:/usr/local/groovy-4.0.24/lib/*\" script"
  },
  {
    id: 89,
    name: "Multi-file program",
    is_archived: true,
  },
  # Archived in 0.64 (compilers 0.28): GCC 14.2.0 was removed from the
  # compilers image — production submissions never adopted these ids and
  # the second toolchain was paying ~45 min compile + ~1 GB image. The
  # compile_cmd paths still reference /usr/local/gcc-14.2.0/, which no
  # longer exists in the image; entries are kept here purely as
  # historical context for any future revival of GCC 14.
  {
    id: 3003,
    name: "C (GCC 14.2.0)",
    is_archived: true,
    source_file: "main.c",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/gcc -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types %s main.c",
    run_cmd: "./a.out"
  },
  {
    id: 3004,
    name: "C++ (GCC 14.2.0)",
    is_archived: true,
    source_file: "main.cpp",
    compile_cmd: "/usr/local/gcc-14.2.0/bin/g++ %s main.cpp",
    run_cmd: "LD_LIBRARY_PATH=/usr/local/gcc-14.2.0/lib64 ./a.out"
  }
]
