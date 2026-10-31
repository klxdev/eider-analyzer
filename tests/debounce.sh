#!/bin/sh
# Debounce: without --sync, a burst of changes is analysed once the input queue is empty, not
# once per change. 40 didChange notifications arrive in one burst, then a hover; the
# document must be analysed (and its diagnostics published) far fewer than 41 times, and
# the last publication must be for the final version.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
server=$root/target/bin/eider-analyzer
wire=$root/target/bin/lsp-wire
T=$root/target/tests
mkdir -p "$T"
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"capabilities":{}}}'
  echo '{"jsonrpc":"2.0","method":"initialized","params":{}}'
  echo '!open fixtures/main.ei 1'
  v=2
  while [ $v -le 41 ]; do echo "!change fixtures/main.ei $v fixtures/main.ei"; v=$((v + 1)); done
  echo '{"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file://${ROOT}/fixtures/main.ei"},"position":{"line":19,"character":8}}}'
  echo '{"jsonrpc":"2.0","id":3,"method":"shutdown"}'
  echo '{"jsonrpc":"2.0","method":"exit"}'
} > "$T/debounce.jsonl"
"$wire" frame "$root/tests" < "$T/debounce.jsonl" > "$T/debounce.in"
"$server" --verbose < "$T/debounce.in" > "$T/debounce.raw" 2> "$T/debounce.err"
code=$?
"$wire" deframe "$root/tests" < "$T/debounce.raw" > "$T/debounce.got"
analyses=$(grep -c "analysed" "$T/debounce.err")
published=$(grep -c "publishDiagnostics" "$T/debounce.got")
last=$(grep "publishDiagnostics" "$T/debounce.got" | tail -1 | sed -n 's/.*"version":\([0-9]*\).*/\1/p')
fail=0
[ "$code" = 0 ] || { echo "FAIL debounce: exit $code"; fail=1; }
[ "$analyses" -lt 41 ] || { echo "FAIL debounce: $analyses analyses for 41 versions"; fail=1; }
[ "$last" = 41 ] || { echo "FAIL debounce: last published version $last, expected 41"; fail=1; }
grep -q '"id":2,"result":{"contents"' "$T/debounce.got" || { echo "FAIL debounce: no hover"; fail=1; }
[ $fail = 0 ] && echo "ok   debounce (41 versions in a burst: $analyses analyses, $published publications, last version $last)"
exit $fail
