# Changelog

eider-analyzer's versions. It ships with the Eider toolchain: its MAJOR.MINOR is always the
toolchain's (eider-lang's `VERSION`), its PATCH its own; before 1.0 a MINOR may break
compatibility. The release process is eider-lang's `docs/site/tooling/releases.md`.

## 0.1.1

Dotted imports (eider-lang issue #91, docs/compiler.md "C8.26"): `import core.sys`,
`import std.{bytes, fs as files}` (across lines, a trailing comma), `import std.encoding as enc`,
the package namespace `import std` with `std.bytes.eq(x)` and `std.time.Duration`, a
dependency's modules (`import json`, `import json.stream`) and the package's own by its name
(`import eider_analyzer.lsp_model as m`). The quoted form still works.

- The lexical stand-in reads every form: a module symbol per group member, aliases, package
  namespaces and the modules their uses imply, the package's own modules and its path and
  git dependencies (eider.toml, eider.lock); `std.time.Duration` refers to the module and its
  item, the last segment of an aliased import to the import.
- Definition and hover on path segments: an import's last segment and alias, and the module
  segment of a namespace use (`bytes` of `std.bytes.eq`), go to the module; hover shows its
  dotted name (`module std.bytes`), and `std` of `import std` what a namespace is. In the
  stand-in, definition on an import goes to its module's file for dotted paths too.
- Completion of module paths: after `import ` (std, core, the package, its dependencies),
  after `import a.` and inside a group's `{ }` (the modules and directories of modules of
  `a`), and in code after a namespace (`std.`: std's modules; `std.time.`: the module's items).
  Namespaces are offered among the names in scope.
- Folding: runs of import statements, a group across lines included.
- Module aliases for completion leave out the path segments that bind no name (`fs` of
  `import std.fs as files`, `bytes` of `std.bytes.eq`).
- An item before a use through a namespace gets a full span that ends before it starts from
  ide.ei (the use's implied import counts as the next item); the adapter ends it at the item's
  last line again, so the outline, folding and completion of locals keep working.
- The sources import in the dotted form (`eiderc migrate-imports`).
- Tests: a session on fixtures/dotted/ (a package of its own: no diagnostics, hover and
  definition on path segments and namespace uses, folding, outline, semantic tokens,
  completion of module paths) and the stand-in on fixtures/dotted/lexical.ei; paths into the
  toolchain are `${EIDER_LANG}` in the goldens.
- Loop labels (`outer: for ...`, eider-lang `SK_LABEL`) in the outline under their function
  (LSP kind Key, detail `outer: for`), with definition, references and hover from `break
  outer` / `continue outer` (tests/sessions/labels.jsonl).

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
