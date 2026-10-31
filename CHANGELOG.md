# Changelog

eider-analyzer's versions. It ships with the Eider toolchain: its MAJOR.MINOR is always the
toolchain's (eider-lang's `VERSION`), its PATCH its own; before 1.0 a MINOR may break
compatibility. The release process is eider-lang's `docs/site/tooling/releases.md`.

## 0.1.0

The first release, with Eider 0.1.0.

- A language server (LSP 3.17 over stdio) written in Eider, on the compiler's own analysis
  (`compiler/ide.ei`'s `ide.analyze`, a path dependency on eider-lang's `compiler`).
- Diagnostics (every compiler diagnostic, in the open file and in imported modules, past
  syntax errors) with the compiler's fixes as quick fixes.
- Document symbols, definition, references, hover, folding ranges, semantic tokens and
  completion (scope, module members, fields, methods, built-in methods, operation traits).
- Debounced analysis on a reader thread; a lexical stand-in for buffers that don't parse;
  UTF-16 positions.
- Package imports through `eider.lock`, capability grants from the compiler.
- json is eider-json 0.1.0, a git dependency, fetched offline from a sibling checkout or the
  toolchain's vendor/json (`EIDER_PKG_OVERRIDE`; eider-lang's U19).
- The language through eider-lang's docs/compiler.md C8.25.
- A Claude Code plugin (`.claude-plugin/marketplace.json`, marketplace `eider`, plugin
  `eider-lsp`).
- Tests: scripted JSON-RPC sessions with goldens, debounce, no diagnostics on eider-lang's
  examples/ and std/, the lexical stand-in, timings.
- `VERSION`, `eider-analyzer --version`, `scripts/version.sh` (check, sync), and
  `scripts/build.sh` refusing a toolchain of another MAJOR.MINOR.
