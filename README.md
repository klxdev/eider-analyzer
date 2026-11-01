# eider-analyzer

A language server for [Eider](../eider-lang) (pronounced EYE-der), written in Eider. It
speaks LSP 3.17 over stdio and gets its knowledge of a program from the Eider compiler
itself (`compiler/ide.ei`'s `ide.analyze`), so diagnostics, positions and types are exactly
the compiler's.

## Features

| LSP | What you get |
|---|---|
| `publishDiagnostics` | the compiler's diagnostic (code, message, `help:` line), for the open file and for an imported module the error is in; E0112 "no `main`" only for the package's main file (eider.toml `main`) |
| `codeAction` (quickfix) | the compiler's machine-applicable fix as an edit |
| `documentSymbol` | hierarchical: types with their fields/variants and methods, variants with their fields, functions (with their loop labels, `outer: for`), constants, traits, tests |
| `definition`, `references` | every name the checker resolved: locals, parameters, items, fields, methods, variants, module aliases, across modules; an import's last path segment and its alias (`sys` of `import core.sys`, `fs` and `files` of `import std.{fs as files}`) and the module segment of a namespace use (`bytes` of `std.bytes.eq`) go to the module's file |
| `hover` | the symbol's signature or type, what it is and where, and the checker's type at the cursor; a type alias shows its target (`type Handler = fn(Request) -> Response`); a module its dotted name (`module std.bytes`), a package namespace (`std` of `import std`) what it is; prelude items the checker records no reference for (`From` in `impl From[E] for T`) and built-in types (`Ref`, `List`, `Map`, ...) get their declaration or a short description |
| `foldingRange` | multi-line items (from their full spans) and runs of import statements (a group across lines, `import std.{` ... `}`, included) |
| `semanticTokens/full` | namespace (import aliases, path segments naming a module), type, enumMember (variants), property (fields), function, method, parameter, variable (locals, constants with `readonly`), interface (traits); `declaration` on definitions |
| `completion` | names in scope at the cursor (locals before it, items, aliases and package namespaces, the prelude's types, variants and traits: Option, Ordering, Less, Copy, From, Default, ...; keywords); after `.`: a module's `pub` items, or the fields and methods of the receiver's type, or the built-in methods of List/String/str/Map/Option/Result/Ref/Box/Mutex/Chan/Task, then the operation-trait methods (`copy`, `compare`, `to_string`, ...) and `take`/`replace`; after a type name also `default` and `from`; module paths: after `import ` the packages (`std`, `core`, the package's own name, its eider.toml dependencies; in no package, the modules beside the file), after `import a.` and in a group's `{ }` the modules and directories of modules of `a` (std and core in the toolchain, a dependency through eider.lock); in code, after a namespace `std.` its modules and after `std.time.` the module's `pub` items |

Documents are kept in memory (full sync; ranged changes are applied too) and passed to the
compiler as overlays. Analysis is debounced: a burst of edits is analysed once, when the
input queue is empty, or when a request needs it. While a buffer doesn't lex or parse, the
compiler has no symbols to give, so a lexical scan of its tokens (lsp_standin.ei) keeps
outline, completion and navigation going. Positions are converted between Eider's columns
(Unicode scalars) and LSP's UTF-16 code units using the document text. Malformed input
(bad headers, bad JSON, wrong types) gets a JSON-RPC error or a log line on stderr, never a
crash; stdout carries only the protocol.

The workspace root of a file is the nearest directory with an `eider.toml`.

The analyzer follows eider-lang's docs/compiler.md through C8.28 (bitwise operators, `()`,
package imports, operation traits, `let mut` and `mut` patterns, Ref[T], string escapes,
type aliases, `for (k, v)`, From, `while let`, labeled loops, Default, method chains across
lines, dotted imports: `import core.sys`, `import std.{bytes, fs as files}`,
`import std.encoding as enc`, the namespace `import std` with `std.bytes.eq(x)`, a package's
own modules by its name, f-strings). The compiler is a path dependency, so its parser and checker are always the
checkout's; what the analyzer adds on top (the stand-in, completion lists, hover texts) is
updated in the same wave as a syntax or IDE-visible change: eider-lang's `scripts/verify.sh`
rebuilds and tests this repository (the "tools" leg, `scripts/check-tools.sh`).

## Build

Needs an Eider toolchain with the compiler's sources, and clang 17+ (or a C11 compiler, as
the toolchain builds programs); nothing else.

```sh
sh scripts/build.sh                                  # the toolchain `eider` picks
EIDER_TOOLCHAIN=../eider-lang sh scripts/build.sh    # an eider-lang checkout
sh tests/run.sh                                      # build, then the tests
```

The toolchain is the one [`eider`](https://github.com/klxdev/eider-lang/blob/main/docs/site/tooling/eider.md)
picks (`scripts/env.sh`): `$EIDER_TOOLCHAIN` (an installed toolchain's directory, or an
eider-lang checkout for unreleased work), else the installed release for `eider.toml`'s
`eider = "0.1"` (what `eider toolchain show` prints here). Install `eider` and the latest
toolchain with eider-lang's `install.sh --toolchain`; without either, the scripts stop with
exit 2 and say so. The analyzer imports the compiler's modules (`import eiderc.ide`), so the
toolchain must have `compiler/`: an eider-lang checkout does, and release toolchains do from
the release after Eider 0.1.0 (eider-lang's `scripts/release.sh`). **The 0.1.0 toolchain has
no `compiler/`**: with it, `scripts/build.sh` stops (exit 2) and says to set
`EIDER_TOOLCHAIN` to an eider-lang checkout (of `v0.1.0`, or main).

The sources import their dependencies by package name (`import eiderc.ide`, `import json`,
`import std.fs`, and their own modules as `import eider_analyzer.lsp_model as m`), which the
compiler resolves through `eider.lock` (eider-lang docs/compiler.md, "C8.3: packages and
modules" and "C8.26: dotted imports"); there is no `deps/` link farm.
`scripts/build.sh` links the toolchain as `target/toolchain`, runs `eider eider-pkg -C .
fetch` and builds `target/bin/eider-analyzer` with the toolchain's compiler (through `eider`,
or directly when `eider` is not on the PATH).

### Dependencies

`eider.toml` points at the toolchain's `compiler` (package `eiderc`) as a path dependency,
`target/toolchain/compiler`; core and std (including `io.read`, which the server reads stdin
with) come from the same toolchain, so the compiler and std are always from one toolchain.

json is [eider-json](https://github.com/klxdev/eider-json) 0.1.1, a git dependency.
`scripts/build.sh` fetches it offline through eider-pkg's `EIDER_PKG_OVERRIDE` (a local
directory standing in for the repository; eider-lang's docs/site/tooling/eider-pkg.md):
`$EIDER_JSON`, else the checkout `../eider-json`, else, when the toolchain is an eider-lang
checkout, its pinned release `.vendor/json` (which its `scripts/vendor.sh fetch json`
fetches and hash-checks); else GitHub. With the override at the locked release,
`eider.lock` is what a fetch from GitHub writes (the same commit and content hash).

### Version

`VERSION` holds eider-analyzer's version, MAJOR.MINOR.PATCH (`CHANGELOG.md`);
`eider-analyzer --version` prints it with the toolchain it was built with
(`eider-analyzer 0.1.0 (eider 0.1.0)`), and the LSP `initialize` reply's `serverInfo` has it.
eider-analyzer ships with the Eider toolchain: its MAJOR.MINOR is always the toolchain's,
its PATCH its own, for fixes between toolchain releases. `scripts/build.sh` stops (exit 2)
when the toolchain's `VERSION` has another MAJOR.MINOR, or none; `eider.toml`'s
`eider = "0.1"` makes the compiler say the same (E0811). `lsp_version.ei`, `eider.toml` and
`.claude-plugin/marketplace.json` carry the version too: `scripts/version.sh check` says
whether they agree with `VERSION` (eider-lang's `scripts/check-tools.sh` runs it),
`scripts/version.sh sync` writes `VERSION` into them. Releases are cut from eider-lang
(`scripts/version.sh bump`, `scripts/release.sh`; its `docs/site/tooling/releases.md`).

## Install

The binary is `target/bin/eider-analyzer`. It needs the Eider toolchain at run time (the
prelude, `core/prelude.ei`, and the C core for `comptime` constants): set `EIDER_ROOT` to
the toolchain it was built with, or leave the binary where it is (`target/core` and `target/std` link
the toolchain's `core/` and `std/`, which the server finds above its own directory, as
eiderc does).

```
eider-analyzer [--sync] [--verbose]   serve on stdin/stdout (logs on stderr)
eider-analyzer --dump <file.ei>       print the analysis of a file
```

`--verbose` logs analysis and request times; `--sync` analyses after every change (no
debounce), which the tests use for a deterministic message order.

## Editor setup

Neovim 0.11+ (built-in client):

```lua
vim.filetype.add({ extension = { ei = "eider" } })
vim.lsp.config("eider_analyzer", {
  cmd = { vim.fn.expand("~/workplace/eider-analyzer/target/bin/eider-analyzer") },
  cmd_env = { EIDER_ROOT = vim.fn.expand("~/workplace/eider-lang") },
  filetypes = { "eider" },
  root_markers = { "eider.toml", ".git" },
})
vim.lsp.enable("eider_analyzer")
```

With LazyVim this can sit in any plugin spec file next to its nvim-lspconfig setup: LazyVim
configures only the servers in its `opts.servers`, and its LSP keymaps and completion
capabilities apply to every client.

Other editors: run the binary as a stdio language server for `*.ei` files (VS Code needs a
small extension that does that; Helix: a `[language-server.eider-analyzer]` with
`command` set to the binary and `environment = { EIDER_ROOT = "..." }`).

## Layout

| File | |
|---|---|
| `lsp_main.ei` | entry: arguments, the reader thread, the main loop |
| `lsp_rpc.ei` | Content-Length framing, JSON-RPC output, logging |
| `lsp_server.ei` | state, documents, dispatch, debounce, publishing diagnostics |
| `lsp_features.ei` | the LSP results, computed from one analysis |
| `lsp_text.ei` | Eider <-> UTF-16 positions, file URIs |
| `lsp_model.ei` | the analysis data the server uses (mirrors ide.ei's contract) |
| `lsp_analysis.ei` | the adapter: the only module that imports the compiler |
| `lsp_standin.ei` | lexical symbols for buffers that don't parse |

Module names are file stems in Eider and must be unique in a program, and the compiler's
modules (lex, parse, check, diag, ide, fs, io, ...) are part of this one, hence `lsp_`.

## Tests

```sh
sh tests/run.sh          # BLESS=1 rewrites the goldens; NOBUILD=1 skips the build
```

`tests/sessions/*.jsonl` are scripted JSON-RPC sessions (`tests/lsp_wire.ei` frames them and
deframes the replies) compared with golden `.out` (and `.err`) files: lifecycle, diagnostics
and quick fixes, navigation, symbols/folding/semantic tokens, completion, UTF-16 with
non-ASCII text, packages, malformed input, the syntax since C8.2 (`fixtures/syntax.ei`:
no diagnostics, aliases in the outline and hover, prelude and Ref hover and completion,
navigation through `let mut` and `mut` patterns) and the new codes with their fixes
(`fixtures/codes.ei`: E0002, E0307, E0306, E0308), loop labels (`fixtures/labels.ei`:
the outline, definition, references, hover), and dotted imports (`fixtures/dotted/`, a
package of its own: every form with no diagnostics, hover and definition on path segments
and namespace uses, folding, completion of module paths). Paths into the toolchain are
written `${EIDER_LANG}` in the goldens. `tests/debounce.sh` sends 40 changes in a burst
and checks they cost one analysis; `tests/clean.sh` opens every `.ei` file of the toolchain's
`std/` (and `examples/`, in an eider-lang checkout) and fails on any diagnostic (they build, so one would be the
analyzer lagging the language); `tests/lexical.sh` compares the lexical stand-in's analysis
(`eider-analyzer --dump-lexical`) of `tests/lexical/*.ei` (`fixtures/syntax.ei` and
`fixtures/dotted/lexical.ei`) with golden files; `tests/perf.sh` prints the time of every request on
the toolchain's `compiler/check.ei` and `compiler/main.ei` (the whole compiler).

## License

MIT (LICENSE).
