# Changelog

eider-analyzer's versions. It ships with the Eider toolchain: its MAJOR.MINOR is always the
toolchain's (eider-lang's `VERSION`), its PATCH its own; before 1.0 a MINOR may break
compatibility. The release process is eider-lang's `docs/site/tooling/releases.md`.

## Unreleased (for Eider 0.7)

- `let PATTERN = e else { ... }` (eider-lang #106, C8.71): the front end folds it into a match, so the
  bound names are definitions over the rest of the block and E0120 is reported (session `let_else`).
- Type arguments at a call, `decode[Order](s)` (eider-lang #149, C8.66), and a binding's type through
  `?`: the compiler's front end provides them (references, definition and hover on the type named
  in the brackets; session `type_args`). Errors in a `test` block now name their own file (#162).

## 0.6.0

For Eider 0.6 (`eider = "0.6"`). Requires eider-json 0.6.0.

- Attributes are written `@[a, b(key = value)]` (eider-lang #155, C8.60): the front end parses the
  group, and completion of an attribute's keys works inside one (after `@[json(` and after the `,`
  of a group). Sessions follow.
- The keys of an `attr` declaration may carry attributes (`@[names_module] with: str = ""`, eider-lang
  #164, C8.63); completion of `std.` lists the new `std.validate` (#101). Locked to the eider-json that
  follows std/serial of 0.6.

## 0.5.0

For Eider 0.5 (`eider = "0.5"`). Requires eider-json 0.5.0.

- Lints (eider-lang #113, #85; C8.56): the findings of `eiderc lint` for the open file's package
  are published with the diagnostics, as warnings (errors for a denied lint) with the lint's name
  as the code, and the quick fix offers the compiler's edit (for `unused_uses`, the `uses` clause
  without the capability). They wait until the program has no errors.
- Expansions (eider-lang #103, C8.57): the custom request `eider/expand` answers, for the symbol
  at a position, with the specializations of reflective bodies (a `@derive`d method for a type)
  as `[{"name", "text"}]`, the text being what `eiderc expand` prints; go to definition from a call
  already leads to the trait's reflective body. Errors inside a specialization name it.
- Severity follows the diagnostic (`Diag.sev`).

## 0.4.0

For Eider 0.4 (`eider = "0.4"`): the language server keeps up with 0.4's language. Requires
eider-json 0.4.0.

- Floating point (eider-lang #43): the lexical stand-in reads a float literal (`lex.Float`) as one
  numeric token, so a buffer with `1.5` or `2e-3f32` keeps its outline and completion.
- Associated types (eider-lang #107, C8.45): the stand-in keeps a trait's `type Item` in the
  outline and skips an impl's.
- Capability polymorphism and `dyn Trait` (eider-lang #46, #18; C8.46, C8.47): the stand-in keeps
  a fn type's `uses` in a parameter's type.
- `is_enum_type` is in the completion list (eider-lang #99, C8.42), and dotted completion knows
  `std.log`, `std.config` and `std.service` (eider-lang #24).

## 0.3.0

For Eider 0.3 (`eider = "0.3"`): the language server keeps up with 0.3's language. Requires
eider-json 0.3.0; every plain string literal in the analyzer interpolates (eider-lang U29).

Default methods (eider-lang issues #45 and #75, docs/compiler.md C8.31): no false diagnostics
for a type that inherits one, definition goes to the trait's method, and completion after
`x.` offers the methods of a trait the file implements for x's type
(tests/sessions/defaults.jsonl).

- Attributes (eider-lang docs/compiler.md, "C8.40"): inside `@name(` and `@alias.name(`, the
  keys of the attribute (the fields of the record type its `attr` declaration is) are
  completed, with their types and defaults; tests/sessions/attributes.
- Comptime reflection (eider-lang docs/compiler.md, "C8.41"): `fields`, `variants` and
  `has_attr` complete as keywords; reflective generic code is analysed by the compiler like
  any other (tests/sessions/reflection).
The pattern-matching finish (eider-lang issues #98 and #105, docs/compiler.md C8.30): a
constant in a pattern goes to the constant, a field pattern's name is a binding, a guard sees
the arm's bindings; no false diagnostics (tests/sessions/patterns.jsonl).

`defer` and `errdefer` (eider-lang issue #15, docs/compiler.md C8.29): completion offers the
words; diagnostics (E0309, E0310 with its quick fix) are the compiler's, and a name used in
deferred code has one reference however many exits run it (tests/sessions/defer.jsonl).

String literals (eider-lang issues #17 and #13, decision U29, docs/compiler.md C8.28): every
plain literal interpolates (`"{x:>8}"`, `{{` for a brace), and raw strings (`r"..."`,
`r#"..."#`, `r"""`) and multi-line `"""` strings exist. The compiler's own front end gives
diagnostics (E0412 with its quick fix), hover, definition and references inside a literal's
braces; the lexical stand-in reads its text as a string and the names in its braces as
references (tests/sessions/strings.jsonl, tests/fixtures/syntax.ei). This repository's
literals with braces are migrated (`eiderc migrate-strings`).

## 0.2.0

For Eider 0.2 (`eider = "0.2"`): eider-lang's 0.2 builds programs only through LLVM (clang
17 or newer; U23) and bootstraps the compiler from a WebAssembly seed (seed/eiderc.wasm; U24).
scripts/env.sh recognises such a checkout (seed/eiderc.wasm, or seed/eiderc.c before).
Nothing else changed.

## 0.1.2

Builds and tests with the toolchain `eider` picks (eider-lang#133) instead of a fixed
eider-lang checkout. scripts/env.sh (sourced by scripts/build.sh and the tests) takes
`$EIDER_TOOLCHAIN` (a toolchain directory or an eider-lang checkout; eider-lang's
scripts/check-tools.sh sets it to its checkout), else the toolchain `eider toolchain show
--json` names for `eider = "0.1"`, else stops with exit 2 and says to install `eider`. The
toolchain must have the compiler's sources (compiler/, the eiderc package the analyzer
imports): eider-lang checkouts do, and release toolchains will from the release after 0.1.0
(eider-lang's scripts/release.sh); with the 0.1.0 toolchain, which has none, build.sh stops
(exit 2) and says to set `EIDER_TOOLCHAIN` to an eider-lang checkout. eider.toml's eiderc
path dependency is now `target/toolchain/compiler`, a link build.sh makes to the toolchain,
so the compiler package, core and std come from one toolchain; `EIDER_LANG` no longer
chooses it. The binary is built with the toolchain's compiler (through `eider`, or directly
when `eider` is not on the PATH) rather than a target/eiderc built from compiler/main.ei.
tests/clean.sh checks the toolchain's std/, and examples/ when it is a checkout. Tested
with the 0.1.0 toolchain plus v0.1.0's compiler/ (the layout of the next release), and with
eider-lang main. No change to the server.

## 0.1.1

Dotted imports (eider-lang issue #91, docs/compiler.md "C8.26"): `import core.sys`,
`import std.{bytes, fs as files}` (across lines, a trailing comma), `import std.encoding as enc`,
the package namespace `import std` with `std.bytes.eq(x)` and `std.time.Duration`, a
dependency's modules (`import json`, `import json.stream`) and the package's own by its name
(`import eider_analyzer.lsp_model as m`). The quoted form still works.
eider.toml requires, and eider.lock pins, eider-json at its tagged v0.1.1 release.

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
