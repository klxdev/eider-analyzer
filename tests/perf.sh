#!/bin/sh
# Response times on large files: eider-lang's compiler/check.ei (~4,400 lines; as an entry
# file it stops at E0107, `spawn` clashes with the builtin, so its references are partial)
# for the outline, semantic tokens and folding, and compiler/main.ei, whose analysis checks
# the whole compiler (27 modules, ~17,000 lines), for navigation. Prints the server's own
# timings (`--verbose`: analysis and per-request milliseconds) and fails only if a response
# is missing or anything takes longer than LIMIT_MS (default 10000), so slow machines don't
# make it flaky.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
server=$root/target/bin/eider-analyzer
wire=$root/target/bin/lsp-wire
T=$root/target/tests
mkdir -p "$T"
# the compiler's sources: the eiderc path dependency in eider.toml (the toolchain's compiler/)
src=$(cd "${EIDER_LANG:-$root/../eider-lang}/compiler" 2>/dev/null && pwd -P)
[ -f "$src/check.ei" ] || { echo "skip perf: no compiler/check.ei in the toolchain (set EIDER_LANG)"; exit 0; }
lines=$(wc -l < "$src/check.ei")
# positions in main.ei are found by searching for code, not fixed line numbers, so edits to the
# compiler don't move them: `pos TEXT OFFSET` prints `"line":L,"character":C` (0-based) for the
# first line of main.ei containing TEXT, OFFSET characters into it
pos() {
  awk -v t="$1" -v o="$2" 'i = index($0, t) { printf "\"line\":%d,\"character\":%d", NR - 1, i - 1 + o; f = 1; exit }
    END { exit !f }' "$src/main.ei"
}
# in `fn report`, the call `diag.demangle(d.msg)` (hover, definition into diag.ei, completion)
# and the field `msg` it assigns (hover after a change); the name of `fn report` (references)
call=$(pos "d2.msg = diag.demangle(d.msg)" 14) &&
  field=$(pos "d2.msg = diag.demangle(d.msg)" 4) &&
  decl=$(pos "fn report(" 3) ||
  { echo "FAIL perf: compiler/main.ei has no 'fn report(' or 'd2.msg = diag.demangle(d.msg)' (update tests/perf.sh)"; exit 1; }
U='"textDocument":{"uri":"file://${ROOT}/check.ei"}'
M='"textDocument":{"uri":"file://${ROOT}/main.ei"}'
cat > "$T/perf.jsonl" <<EOF
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":"file://\${ROOT}","capabilities":{}}}
{"jsonrpc":"2.0","method":"initialized","params":{}}
!open check.ei 1
{"jsonrpc":"2.0","id":2,"method":"textDocument/documentSymbol","params":{$U}}
{"jsonrpc":"2.0","id":3,"method":"textDocument/semanticTokens/full","params":{$U}}
{"jsonrpc":"2.0","id":4,"method":"textDocument/foldingRange","params":{$U}}
!open main.ei 1
{"jsonrpc":"2.0","id":5,"method":"textDocument/hover","params":{$M,"position":{$call}}}
{"jsonrpc":"2.0","id":6,"method":"textDocument/definition","params":{$M,"position":{$call}}}
{"jsonrpc":"2.0","id":7,"method":"textDocument/references","params":{$M,"position":{$decl},"context":{"includeDeclaration":true}}}
{"jsonrpc":"2.0","id":8,"method":"textDocument/completion","params":{$M,"position":{$call}}}
{"jsonrpc":"2.0","id":11,"method":"textDocument/semanticTokens/full","params":{$M}}
!change main.ei 2 main.ei
{"jsonrpc":"2.0","id":9,"method":"textDocument/hover","params":{$M,"position":{$field}}}
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
echo "perf: compiler/check.ei ($lines lines) and compiler/main.ei, $(wc -c < "$T/perf.in") bytes of input, wall time ${total} ms:"
sed 's/^eider-analyzer: /  /' "$T/perf.err" | grep -v "^  opened"
fail=0
[ "$responses" = 11 ] || { echo "FAIL perf: $responses of 11 responses"; fail=1; }
limit=${LIMIT_MS:-10000}
slow=$(sed -n 's/.* \([0-9][0-9]*\) ms.*/\1/p' "$T/perf.err" | awk -v l="$limit" '$1 > l' | head -1)
[ -z "$slow" ] || { echo "FAIL perf: something took ${slow} ms (limit $limit)"; fail=1; }
grep -q '"id":2,"result":\[{' "$T/perf.got" || { echo "FAIL perf: no document symbols"; fail=1; }
grep -q '"id":6,"result":{"uri":"file://${ROOT}/diag.ei"' "$T/perf.got" || { echo "FAIL perf: no definition of diag.demangle in diag.ei"; fail=1; }
[ $fail = 0 ] && echo "ok   perf"
exit $fail
