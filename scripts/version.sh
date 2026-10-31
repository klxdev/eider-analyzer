#!/bin/sh
# eider-analyzer's version: VERSION, MAJOR.MINOR.PATCH (CHANGELOG.md).
#
#   scripts/version.sh            print the version
#   scripts/version.sh check      VERSION, lsp_version.ei, eider.toml (`version`, and `eider`:
#                                 its MAJOR.MINOR) and .claude-plugin/marketplace.json agree
#   scripts/version.sh sync       write VERSION into the others
#
# eider-analyzer ships with the Eider toolchain (eider-lang's docs/site/tooling/releases.md):
# its MAJOR.MINOR is always the toolchain's, its PATCH its own. eider-lang's
# `scripts/version.sh bump` writes VERSION here and runs `sync`; scripts/build.sh refuses a
# toolchain of another MAJOR.MINOR.
cd "$(dirname "$0")/.." || exit 1
v=$(tr -d ' \n' < VERSION 2>/dev/null)
echo "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "version.sh: VERSION must be MAJOR.MINOR.PATCH, not \`$v\`" >&2; exit 1; }
series=${v%.*}
# the values each file holds
of_ei() { sed -n 's/^pub const VERSION: str = "\(.*\)"$/\1/p' lsp_version.ei; }
of_toml() { sed -n "s/^$1 = \"\(.*\)\"\$/\1/p" eider.toml | head -1; }
of_plugin() { sed -n 's/^ *"version": "\(.*\)",*$/\1/p' .claude-plugin/marketplace.json; }
case "${1:-}" in
  "") echo "$v" ;;
  check)
    bad=0
    want() { [ "$2" = "$3" ] || { echo "FAIL eider-analyzer version: $1 says \`$2\`, VERSION says $3" >&2; bad=1; }; }
    want lsp_version.ei "$(of_ei)" "$v"
    want "eider.toml version" "$(of_toml version)" "$v"
    want "eider.toml eider" "$(of_toml eider)" "$series"
    for p in $(of_plugin); do want .claude-plugin/marketplace.json "$p" "$v"; done
    [ -n "$(of_plugin)" ] || { echo "FAIL eider-analyzer version: no \"version\" in .claude-plugin/marketplace.json" >&2; bad=1; }
    [ $bad = 0 ] && echo "ok   eider-analyzer $v (VERSION, lsp_version.ei, eider.toml, marketplace.json)"
    exit $bad ;;
  sync)
    # POSIX sed and awk only (no sed -i): rewrite <file> <program> runs awk over it
    rewrite() { awk -v v="$v" -v s="$series" "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
    rewrite lsp_version.ei '/^pub const VERSION: str = "/ { print "pub const VERSION: str = \"" v "\""; next } { print }'
    # the first `version =` is [package]'s
    rewrite eider.toml '!d && /^version = "/ { print "version = \"" v "\""; d = 1; next } /^eider = "/ { print "eider = \"" s "\""; next } { print }'
    rewrite .claude-plugin/marketplace.json '/^ *"version": "/ { sub(/"version": "[^"]*"/, "\"version\": \"" v "\"") } { print }'
    exec sh "$0" check ;;
  *) echo "usage: scripts/version.sh [check | sync]" >&2; exit 2 ;;
esac
