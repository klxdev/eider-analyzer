#!/bin/sh
# Build target/bin/eider-analyzer.
#
#   scripts/build.sh            fetch the dependencies (eider-pkg fetch), then build
#
# The toolchain is the one scripts/env.sh finds: $EIDER_TOOLCHAIN, else the one `eider`
# picks for this repository (eider.toml's `eider`), with the compiler's sources (compiler/,
# the eiderc package the analyzer imports). target/toolchain links it: eider.toml's eiderc
# path dependency is target/toolchain/compiler. The sources import their dependencies by
# package name (`import eiderc.ide`, `import json`, `import std.fs`), which the compiler
# resolves through eider.lock: there is no deps/ link farm. The toolchain's compiler builds
# the binary (`eider build`). target/core and target/std link the toolchain's, so the binary
# finds the prelude (core/prelude.ei) and `std/...` as eiderc does: in the parent of the
# directory that holds it.
set -e
here=$(cd "$(dirname "$0")/.." && pwd -P)
sh "$here/scripts/version.sh" check >/dev/null || exit 2
. "$here/scripts/env.sh"
# json is a git package (eider-json). Offline, eider-pkg takes it from a local directory
# (EIDER_PKG_OVERRIDE, eider-lang's docs/site/tooling/eider-pkg.md): $EIDER_JSON, else the
# checkout ../eider-json, else, when the toolchain is an eider-lang checkout, its pinned
# release .vendor/json (fetched and hash-checked there by its scripts/vendor.sh); else
# GitHub. eider.lock keeps the git source and the content hash; the fetch runs every time,
# since the store copy it points at may not be there yet.
case ",$EIDER_PKG_OVERRIDE," in
  *,json=*) ;;
  *)
    json=${EIDER_JSON:-}
    [ -n "$json" ] || { [ -f "$here/../eider-json/eider.toml" ] && json=$here/../eider-json; }
    if [ -z "$json" ] && [ -f "$toolchain/vendor.lock" ]; then sh "$toolchain/scripts/vendor.sh" fetch json >&2 && json=$toolchain/.vendor/json; fi
    [ -z "$json" ] || EIDER_PKG_OVERRIDE="${EIDER_PKG_OVERRIDE:+$EIDER_PKG_OVERRIDE,}json=$(cd "$json" && pwd -P)"
    ;;
esac
export EIDER_PKG_OVERRIDE
mkdir -p "$here/target/bin"
ln -sfn "$toolchain" "$here/target/toolchain"
ln -sfn "$toolchain/core" "$here/target/core"
ln -sfn "$toolchain/std" "$here/target/std"
eider_pkg -C "$here" fetch > /dev/null
ei build "$here/lsp_main.ei" -o "$here/target/bin/eider-analyzer"
echo "built $here/target/bin/eider-analyzer (Eider $theirs at $toolchain; $chosen)"
