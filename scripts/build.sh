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
# The toolchain's VERSION must have this repository's MAJOR.MINOR (VERSION; exit 2 otherwise).
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
toolchain=$(cd "${EIDER_LANG:-$here/../eider-lang}" 2>/dev/null && pwd -P) || { echo "build.sh: set EIDER_LANG to the eider-lang checkout" >&2; exit 2; }
[ -x "$toolchain/scripts/ei" ] || { echo "build.sh: $toolchain is not an eider-lang checkout (no scripts/ei); set EIDER_LANG" >&2; exit 2; }
# eider-analyzer ships with the toolchain: the same MAJOR.MINOR (VERSION here and there;
# before 1.0 a MINOR may break compatibility), its own PATCH (CHANGELOG.md)
sh "$here/scripts/version.sh" check >/dev/null || exit 2
mine=$(tr -d ' \n' < "$here/VERSION")
theirs=; [ -f "$toolchain/VERSION" ] && theirs=$(tr -d ' \n' < "$toolchain/VERSION")
if [ -z "$theirs" ]; then
  echo "build.sh: the toolchain at $toolchain has no VERSION (it is older than Eider 0.1.0); eider-analyzer $mine needs Eider ${mine%.*}.x" >&2
  exit 2
fi
if [ "${theirs%.*}" != "${mine%.*}" ]; then
  echo "build.sh: eider-analyzer $mine needs an Eider ${mine%.*}.x toolchain, but $toolchain is Eider $theirs; use the eider-analyzer release made with that toolchain (docs/site/tooling/releases.md in eider-lang)" >&2
  exit 2
fi
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
