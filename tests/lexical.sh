#!/bin/sh
# The lexical stand-in (lsp_standin.ei), which keeps outline, completion and navigation going
# when the compiler has no symbols for a buffer: `eider-analyzer --dump-lexical` of each
# tests/lexical/*.ei against the golden <name>.out next to it (BLESS=1 rewrites them).
# fixtures/syntax.ei (linked as tests/lexical/syntax.ei) has every form since
# docs/compiler.md C8.2: no local named `mut`, `for (k, v)` and `|inout x|` bindings, type
# aliases with their targets, `std/fs` found through the toolchain, labels not taken for names.
# fixtures/dotted/lexical.ei (linked as tests/lexical/dotted.ei; "C8.26") has every dotted
# import: a module per group member, aliases, the std namespace (`std.random.below`: the
# module segment and the item), the package's own modules found from its eider.toml.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
server=$root/target/bin/eider-analyzer
lang=$(cd "${EIDER_LANG:-$root/../eider-lang}" 2>/dev/null && pwd -P)
T=$root/target/tests
mkdir -p "$T"
fail=0
for f in tests/lexical/*.ei; do
  name=$(basename "$f" .ei)
  EIDER_ROOT=$lang "$server" --dump-lexical "$f" 2>&1 | sed -e "s|$root/|\${ROOT}/|g" -e "s|$lang/|\${EIDER_LANG}/|g" > "$T/lexical_$name.got"
  [ -n "$BLESS" ] && cp "$T/lexical_$name.got" "tests/lexical/$name.out"
  if cmp -s "$T/lexical_$name.got" "tests/lexical/$name.out"; then
    echo "ok   lexical $name ($(grep -c '^sym' "$T/lexical_$name.got") symbols)"
  else
    echo "FAIL lexical $name"
    diff "tests/lexical/$name.out" "$T/lexical_$name.got" | head -20
    fail=1
  fi
done
exit $fail
