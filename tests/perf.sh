#!/bin/sh
# Response times on a large file: eider-lang's compiler/check.ei (~4,200 lines; the analysis
# loads the whole compiler, ~16,000 lines, for its diagnostics). Prints the server's own
# timings (`--verbose`: analysis and per-request milliseconds) and fails only if a response
# is missing or anything takes longer than LIMIT_MS (default 10000), so slow machines don't
# make it flaky.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
server=$root/target/bin/eider-analyzer
wire=$root/target/bin/lsp-wire
T=$root/target/tests
mkdir -p "$T"
src=$root/deps/eiderc
[ -f "$src/check.ei" ] || { echo "skip perf: no deps/eiderc/check.ei (run scripts/build.sh)"; exit 0; }
lines=$(wc -l < "$src/check.ei")
U='"textDocument":{"uri":"file://${ROOT}/check.ei"}'
cat > "$T/perf.jsonl" <<EOF
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file://\${ROOT}","capabilities":{}}}
{"jsonrpc":"2.0","method":"initialized","params":{}}
!open check.ei 1
{"jsonrpc":"2.0","id":2,"method":"textDocument/documentSymbol","params":{$U}}
{"jsonrpc":"2.0","id":3,"method":"textDocument/semanticTokens/full","params":{$U}}
{"jsonrpc":"2.0","id":4,"method":"textDocument/foldingRange","params":{$U}}
{"jsonrpc":"2.0","id":5,"method":"textDocument/hover","params":{$U,"position":{"line":1184,"character":14}}}
{"jsonrpc":"2.0","id":6,"method":"textDocument/definition","params":{$U,"position":{"line":1184,"character":14}}}
{"jsonrpc":"2.0","id":7,"method":"textDocument/references","params":{$U,"position":{"line":1140,"character":4},"context":{"includeDeclaration":true}}}
{"jsonrpc":"2.0","id":8,"method":"textDocument/completion","params":{$U,"position":{"line":1184,"character":14}}}
!change check.ei 2 check.ei
{"jsonrpc":"2.0","id":9,"method":"textDocument/hover","params":{$U,"position":{"line":1184,"character":14}}}
{"jsonrpc":"2.0","id":10,"method":"shutdown"}
{"jsonrpc":"2.0","method":"exit"}
EOF
"$wire" frame "$src" < "$T/perf.jsonl" > "$T/perf.in"
start=$(date +%s%N)
"$server" --sync --verbose < "$T/perf.in" > "$T/perf.raw" 2> "$T/perf.err"
end=$(date +%s%N)
"$wire" deframe "$src" < "$T/perf.raw" > "$T/perf.got"
total=$(( (end - start) / 1000000 ))
responses=$(grep -c '"id":[0-9]*,"result"' "$T/perf.got")
echo "perf: compiler/check.ei ($lines lines), $(wc -c < "$T/perf.in") bytes of input, wall time ${total} ms:"
sed 's/^eider-analyzer: /  /' "$T/perf.err" | grep -v "^  opened"
fail=0
[ "$responses" = 10 ] || { echo "FAIL perf: $responses of 10 responses"; fail=1; }
limit=${LIMIT_MS:-10000}
slow=$(sed -n 's/.* \([0-9][0-9]*\) ms.*/\1/p' "$T/perf.err" | awk -v l="$limit" '$1 > l' | head -1)
[ -z "$slow" ] || { echo "FAIL perf: something took ${slow} ms (limit $limit)"; fail=1; }
grep -q '"id":2,"result":\[{' "$T/perf.got" || { echo "FAIL perf: no document symbols"; fail=1; }
grep -q '"id":6,"result":{"uri"' "$T/perf.got" || { echo "FAIL perf: no definition"; fail=1; }
[ $fail = 0 ] && echo "ok   perf"
exit $fail
