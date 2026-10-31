#!/bin/sh
# The test client: replays the scripted JSON-RPC sessions in tests/sessions/*.jsonl against
# the server and compares what it sends back with the golden files next to them.
#
#   sh tests/run.sh            build (scripts/build.sh), then run every session
#   BLESS=1 sh tests/run.sh    rewrite the goldens from the current output (review the diff!)
#   NOBUILD=1 sh tests/run.sh  use the binaries as they are
#
# Each session runs `eider-analyzer --sync` (analysis after every change, so the order of
# messages doesn't depend on timing) with the framed script on stdin (tests/lsp_wire.ei
# frames it). stdout is deframed to one message per line and compared with <name>.out;
# stderr (the server's log) with <name>.err when that file exists; the exit code with the
# `# exit N` line of the script (default 0). tests/debounce.sh and tests/perf.sh are run
# after the sessions.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
if [ -z "$NOBUILD" ]; then
  sh scripts/build.sh >/dev/null || { echo "FAIL build"; exit 1; }
fi
# the toolchain and the compiler scripts/build.sh made (package imports need it)
toolchain=$(cd "${EIDER_LANG:-$root/../eider-lang}" && pwd -P)
if [ -z "$NOBUILD" ] || [ ! -x target/bin/lsp-wire ]; then
  EIDER_ROOT=$toolchain target/eiderc build tests/lsp_wire.ei -o target/bin/lsp-wire >/dev/null || { echo "FAIL build lsp-wire"; exit 1; }
fi
server=$root/target/bin/eider-analyzer
wire=$root/target/bin/lsp-wire
T=$root/target/tests
mkdir -p "$T"
fail=0
for s in tests/sessions/*.jsonl; do
  name=$(basename "$s" .jsonl)
  want_exit=$(sed -n 's/^# exit \([0-9]*\)$/\1/p' "$s")
  [ -n "$want_exit" ] || want_exit=0
  "$wire" frame "$root/tests" < "$s" > "$T/$name.in" || { echo "FAIL $name: cannot frame"; fail=1; continue; }
  "$server" --sync < "$T/$name.in" > "$T/$name.raw" 2> "$T/$name.stderr"
  code=$?
  "$wire" deframe "$root/tests" < "$T/$name.raw" > "$T/$name.got"
  sed "s|$root/tests|\${ROOT}|g" "$T/$name.stderr" > "$T/$name.errgot"
  if [ -n "$BLESS" ]; then
    cp "$T/$name.got" "tests/sessions/$name.out"
    [ -f "tests/sessions/$name.err" ] && cp "$T/$name.errgot" "tests/sessions/$name.err"
  fi
  ok=1
  cmp -s "$T/$name.got" "tests/sessions/$name.out" || { ok=0; echo "FAIL $name (stdout)"; diff "tests/sessions/$name.out" "$T/$name.got" | head -20; }
  if [ -f "tests/sessions/$name.err" ]; then
    cmp -s "$T/$name.errgot" "tests/sessions/$name.err" || { ok=0; echo "FAIL $name (stderr)"; diff "tests/sessions/$name.err" "$T/$name.errgot" | head -10; }
  fi
  [ "$code" = "$want_exit" ] || { ok=0; echo "FAIL $name: exit $code, expected $want_exit"; }
  if [ $ok = 1 ]; then echo "ok   $name ($(wc -l < "$T/$name.got") messages)"; else fail=1; fi
done
sh tests/debounce.sh || fail=1
sh tests/perf.sh || fail=1
[ $fail = 0 ] && echo "ALL PASSED"
exit $fail
