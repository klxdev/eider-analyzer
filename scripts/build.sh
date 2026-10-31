#!/bin/sh
# Build target/bin/eider-analyzer.
#
#   scripts/build.sh            fetch dependencies if deps/ is missing, then build
#
# The toolchain is the eider-lang checkout that deps/core points into (eider-pkg links deps/core
# and deps/std from the toolchain that ran it). To fetch, set EIDER_LANG to the eider-lang
# checkout (default: ../eider-lang next to this repository). Building needs only that
# checkout and a C11 compiler ($CC, default cc): eider-lang's scripts/ei builds the compiler
# from its seed. target/core links the toolchain's core/, so the binary finds the prelude
# (core/prelude.ei) as eiderc does: in the parent of the directory that holds it.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
if [ ! -e "$here/deps/core" ] || [ ! -e "$here/deps/eiderc" ] || [ ! -e "$here/deps/json" ]; then
  lang=${EIDER_LANG:-$here/../eider-lang}
  [ -x "$lang/scripts/eider-pkg" ] || { echo "build.sh: set EIDER_LANG to the eider-lang checkout (no $lang/scripts/eider-pkg)" >&2; exit 2; }
  "$lang/scripts/eider-pkg" -C "$here" fetch
fi
toolchain=$(cd -P "$here/deps/core/.." && pwd)
mkdir -p "$here/target/bin"
ln -sfn "$toolchain/core" "$here/target/core"
"$toolchain/scripts/ei" build "$here/lsp_main.ei" -o "$here/target/bin/eider-analyzer"
echo "built $here/target/bin/eider-analyzer (toolchain $toolchain)"
