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
| `documentSymbol` | hierarchical: types with their fields/variants and methods, variants with their fields, functions, constants, traits, tests |
| `definition`, `references` | every name the checker resolved: locals, parameters, items, fields, methods, variants, module aliases, across modules |
| `hover` | the symbol's signature or type, what it is and where, and the checker's type at the cursor |
| `foldingRange` | multi-line items (from their full spans) and runs of imports |
| `semanticTokens/full` | namespace (import aliases), type, enumMember (variants), property (fields), function, method, parameter, variable (locals, constants with `readonly`), interface (traits); `declaration` on definitions |
| `completion` | names in scope at the cursor (locals before it, items, aliases, keywords); after `.`: a module's `pub` items, or the fields and methods of the receiver's type, or List/String/Map/Option/Result methods |

Documents are kept in memory (full sync; ranged changes are applied too) and passed to the
compiler as overlays. Analysis is debounced: a burst of edits is analysed once, when the
input queue is empty, or when a request needs it. While a buffer doesn't lex or parse, the
compiler has no symbols to give, so a lexical scan of its tokens (lsp_standin.ei) keeps
outline, completion and navigation going. Positions are converted between Eider's columns
(Unicode scalars) and LSP's UTF-16 code units using the document text. Malformed input
(bad headers, bad JSON, wrong types) gets a JSON-RPC error or a log line on stderr, never a
crash; stdout carries only the protocol.

The workspace root of a file is the nearest directory with an `eider.toml`.

## Build

Needs an [eider-lang](../eider-lang) checkout and a C11 compiler; nothing else.

```sh
EIDER_LANG=/path/to/eider-lang sh scripts/build.sh   # fetches deps/ on first use
```

This runs `eider-lang/scripts/eider-pkg -C . fetch` (the path dependencies in eider.toml:
the compiler package `eiderc` and `json`), then `scripts/ei build lsp_main.ei -o
target/bin/eider-analyzer`. Re-run `eider-pkg -C . fetch` after the compiler gains a file
(deps/ links each file).

### Dependencies

`eider.toml` points at eider-lang's `compiler` (package `eiderc`) and `packages/json`; core
and std (including `io.read`, which the server reads stdin with) come from the same
eider-lang checkout's toolchain.

## Install

The binary is `target/bin/eider-analyzer`. It needs the Eider toolchain at run time (the
prelude, `core/prelude.ei`, and the C core for `comptime` constants): set `EIDER_ROOT` to
the eider-lang checkout, or leave the binary where it is (`target/core` links the toolchain's
`core/`, which the server finds above its own directory, as eiderc does).

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
non-ASCII text, packages, malformed input. `tests/debounce.sh` sends 40 changes in a burst
and checks they cost one analysis; `tests/perf.sh` prints the time of every request on
eider-lang's `compiler/check.ei` and `compiler/main.ei` (the whole compiler).

## License

MIT (LICENSE).
