#!/bin/sh
# No false diagnostics on the language's own code: every .ei file under the toolchain's
# examples/ and std/ (eider-lang, $EIDER_LANG, default ../eider-lang) is opened in the
# server, one at a time, and every publishDiagnostics it sends must be empty. These files
# build with the current compiler, so any diagnostic is the analyzer lagging the language
# (for example "expected `=`" on `let mut`, before the analyzer was rebuilt for C8.6).
# Also fixtures/syntax.ei, which uses the syntax of docs/compiler.md C8.2 to C8.25 (fixtures/dotted/ has C8.26's dotted imports: tests/sessions/dotted.jsonl).
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
server=$root/target/bin/eider-analyzer
wire=$root/target/bin/lsp-wire
T=$root/target/tests
mkdir -p "$T"
lang=$(cd "${EIDER_LANG:-$root/../eider-lang}" 2>/dev/null && pwd -P)
[ -d "$lang/examples" ] && [ -d "$lang/std" ] || { echo "skip clean: no examples/ and std/ in the toolchain (set EIDER_LANG)"; exit 0; }
(cd "$lang" && find examples std -name '*.ei' -not -path '*/deps/*' | sort) > "$T/clean.files"
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file://${ROOT}","capabilities":{}}}'
  echo '{"jsonrpc":"2.0","method":"initialized","params":{}}'
  while read -r f; do
    echo "!open $f 1"
    echo "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{\"textDocument\":{\"uri\":\"file://\${ROOT}/$f\"}}}"
  done < "$T/clean.files"
  echo '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
  echo '{"jsonrpc":"2.0","method":"exit"}'
} > "$T/clean.jsonl"
"$wire" frame "$lang" < "$T/clean.jsonl" > "$T/clean.in" || { echo "FAIL clean: cannot frame"; exit 1; }
EIDER_ROOT=$lang "$server" --sync < "$T/clean.in" > "$T/clean.raw" 2> "$T/clean.err"
code=$?
"$wire" deframe "$lang" < "$T/clean.raw" > "$T/clean.got"
# the fixture, through its own session root
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file://${ROOT}/fixtures","capabilities":{}}}'
  echo '{"jsonrpc":"2.0","method":"initialized","params":{}}'
  echo '!open fixtures/syntax.ei 1'
  echo '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
  echo '{"jsonrpc":"2.0","method":"exit"}'
} > "$T/clean2.jsonl"
"$wire" frame "$root/tests" < "$T/clean2.jsonl" | "$server" --sync 2>/dev/null | "$wire" deframe "$root/tests" >> "$T/clean.got"
n=$(wc -l < "$T/clean.files")
opened=$(grep '"method":"textDocument/publishDiagnostics"' "$T/clean.got" | grep -o '"uri":"[^"]*"' | sort -u | wc -l)
grep '"method":"textDocument/publishDiagnostics"' "$T/clean.got" | grep -v '"diagnostics":\[\]' > "$T/clean.bad"
fail=0
[ "$code" = 0 ] || { echo "FAIL clean: server exit $code"; fail=1; }
[ "$opened" -ge $((n + 1)) ] || { echo "FAIL clean: diagnostics for $opened of $((n + 1)) files"; fail=1; }
if [ -s "$T/clean.bad" ]; then
  echo "FAIL clean: diagnostics on files that build:"
  sed 's/^.*"uri":"file:\/\/\([^"]*\)".*"message":"\([^"]*\)".*$/  \1: \2/' "$T/clean.bad" | head -20
  fail=1
fi
[ $fail = 0 ] && echo "ok   clean ($n files of examples/ and std/, and fixtures/syntax.ei: no diagnostics)"
exit $fail
