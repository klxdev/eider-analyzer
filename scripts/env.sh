# Sourced by scripts/build.sh and the tests (with `here` set to this repository): the Eider
# toolchain and the compiler sources the analyzer is built from.
#
# The toolchain is the one `eider` (eider-lang's docs/site/tooling/eider.md) picks, the first
# of:
#   1. $EIDER_TOOLCHAIN: a toolchain directory (bin/eiderc) or an eider-lang checkout
#      (scripts/ei), for testing against unreleased work (eider-lang's scripts/check-tools.sh
#      sets it to its checkout);
#   2. `eider toolchain show --json` here: the installed toolchain for eider.toml's
#      `eider = "MAJOR.MINOR"` (its newest installed patch; else eider's default);
#   3. neither: exit 2, saying to install eider (install.sh).
# Its VERSION must have this repository's MAJOR.MINOR (VERSION; exit 2 otherwise).
#
# The analyzer imports the compiler's modules (package eiderc, `import eiderc.ide`), so the
# toolchain must have the compiler's sources, compiler/: an eider-lang checkout has them, and
# the release toolchains do from the release after Eider 0.1.0 (eider-lang's
# scripts/release.sh). The 0.1.0 toolchain has none: with it, exit 2, saying to set
# EIDER_TOOLCHAIN to an eider-lang checkout. eider.toml's eiderc path dependency is
# target/toolchain/compiler, and target/toolchain links the toolchain, so the compiler
# package, core and std all come from the one toolchain.
#
# Sets toolchain, chosen (why it was picked), theirs (its VERSION) and EIDER_TOOLCHAIN and
# EIDER_ROOT (exported, so every later command uses the same one), and defines `ei <args>`
# and `eider_pkg <args>`: the toolchain's compiler and eider-pkg, through `eider` when it is
# on the PATH, else (EIDER_TOOLCHAIN only) the toolchain's own programs.
die() { echo "$(basename "$0"): $*" >&2; exit 2; }
if [ -n "${EIDER_TOOLCHAIN:-}" ]; then
  toolchain=$(cd "$EIDER_TOOLCHAIN" 2>/dev/null && pwd -P) || die "EIDER_TOOLCHAIN=$EIDER_TOOLCHAIN: no such directory"
  chosen="EIDER_TOOLCHAIN"
elif command -v eider >/dev/null 2>&1; then
  shown=$(cd "$here" && eider toolchain show --json 2>/dev/null) || true
  toolchain=$(printf '%s\n' "$shown" | sed -n 's/^{.*"path":"\([^"]*\)".*/\1/p')
  if [ -z "$toolchain" ]; then
    why=$(printf '%s\n' "$shown" | sed -n 's/^{"error":"\(.*\)"}$/\1/p' | sed 's/\\"/"/g')
    die "eider found no toolchain for $here: ${why:-eider toolchain show --json printed \`$shown\`}"
  fi
  chosen="eider toolchain show: $(printf '%s\n' "$shown" | sed -n 's/.*"why":"\(.*\)"}$/\1/p' | sed 's/\\"/"/g')"
else
  die "no Eider toolchain: no \`eider\` on the PATH and no EIDER_TOOLCHAIN; install eider (gh release download --repo klxdev/eider-lang --pattern install.sh && sh install.sh --toolchain; eider-lang's docs/site/tooling/eider.md), or set EIDER_TOOLCHAIN to an Eider toolchain or an eider-lang checkout"
fi
if [ -x "$toolchain/scripts/ei" ] && [ -f "$toolchain/seed/eiderc.c" ]; then
  tc_eiderc=$toolchain/scripts/ei; tc_pkg=$toolchain/scripts/eider-pkg
elif [ -x "$toolchain/bin/eiderc" ]; then
  tc_eiderc=$toolchain/bin/eiderc; tc_pkg=$toolchain/bin/eider-pkg
else
  die "$toolchain ($chosen) is neither an Eider toolchain (bin/eiderc) nor an eider-lang checkout (scripts/ei)"
fi
# eider-analyzer ships with the toolchain: the same MAJOR.MINOR (VERSION here and there;
# before 1.0 a MINOR may break compatibility), its own PATCH (CHANGELOG.md)
mine=$(tr -d ' \n' < "$here/VERSION")
theirs=; [ -f "$toolchain/VERSION" ] && theirs=$(tr -d ' \n' < "$toolchain/VERSION")
[ -n "$theirs" ] || die "the toolchain at $toolchain has no VERSION (it is older than Eider 0.1.0); eider-analyzer $mine needs Eider ${mine%.*}.x"
[ "${theirs%.*}" = "${mine%.*}" ] || die "eider-analyzer $mine needs an Eider ${mine%.*}.x toolchain, but $toolchain ($chosen) is Eider $theirs; \`eider toolchain install ${mine%.*}\`, or use the eider-analyzer release made with that toolchain (docs/site/tooling/releases.md in eider-lang)"
[ -f "$toolchain/compiler/eider.toml" ] || die "the Eider $theirs toolchain at $toolchain ($chosen) has no compiler sources (compiler/), which the analyzer imports; release toolchains have them after Eider 0.1.0: set EIDER_TOOLCHAIN to an eider-lang checkout (of v$theirs, or main)"
EIDER_TOOLCHAIN=$toolchain
EIDER_ROOT=$toolchain
export EIDER_TOOLCHAIN EIDER_ROOT
if command -v eider >/dev/null 2>&1; then
  ei() { eider eiderc "$@"; }
  eider_pkg() { eider eider-pkg "$@"; }
else
  EIDERC=$tc_eiderc
  export EIDERC
  ei() { "$tc_eiderc" "$@"; }
  eider_pkg() { "$tc_pkg" "$@"; }
fi
