#!/bin/sh
# Build target/bin/eider-analyzer.
#
#   scripts/build.sh            fetch dependencies if eider.lock is missing, then build
#
# The toolchain is the eider-lang checkout $EIDER_LANG (default: ../eider-lang next to this
# repository), the one eider.toml's path dependencies point into. The sources import their
# dependencies by package name (`import "eiderc/ide"`, `import "json"`, `import "std/fs"`),
# which the compiler resolves through eider.lock: there is no deps/ link farm. Package
# imports need an eiderc newer than eider-lang's seed (until the seed knows them), so this
# builds target/eiderc from the checkout's compiler/ with its scripts/ei (only a C11
# compiler: $CC, default cc) when that is missing or older than compiler/, std/ or core/.
# target/core and target/std link the toolchain's, so the binary finds the prelude
# (core/prelude.ei) and `std/...` as eiderc does: in the parent of the directory that holds it.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
toolchain=$(cd "${EIDER_LANG:-$here/../eider-lang}" 2>/dev/null && pwd -P) || { echo "build.sh: set EIDER_LANG to the eider-lang checkout" >&2; exit 2; }
[ -x "$toolchain/scripts/ei" ] || { echo "build.sh: $toolchain is not an eider-lang checkout (no scripts/ei); set EIDER_LANG" >&2; exit 2; }
if [ ! -f "$here/eider.lock" ]; then
  "$toolchain/scripts/eider-pkg" -C "$here" fetch
fi
mkdir -p "$here/target/bin"
eiderc=$here/target/eiderc
if [ ! -x "$eiderc" ] || [ -n "$(find "$toolchain/compiler" "$toolchain/std" "$toolchain/core" -name '*.ei' -newer "$eiderc" 2>/dev/null | head -1)" ]; then
  EIDER_CACHE=off "$toolchain/scripts/ei" build "$toolchain/compiler/main.ei" -o "$eiderc"
fi
ln -sfn "$toolchain/core" "$here/target/core"
ln -sfn "$toolchain/std" "$here/target/std"
EIDER_ROOT=$toolchain "$eiderc" build "$here/lsp_main.ei" -o "$here/target/bin/eider-analyzer"
echo "built $here/target/bin/eider-analyzer (toolchain $toolchain)"
