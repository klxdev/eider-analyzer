# eider-lsp for Claude Code

Gives Claude Code code intelligence for Eider (`.ei`) files through eider-analyzer:
diagnostics after edits, go to definition, references, hover.

```sh
sh scripts/build.sh                                   # builds target/bin/eider-analyzer
claude plugin marketplace add /path/to/eider-analyzer # this repo is the marketplace "eider"
claude plugin install eider-lsp@eider
```

The server is declared in `.claude-plugin/marketplace.json` (`lspServers`). Its command is
an absolute path to the built binary and `EIDER_ROOT` points at the eider-lang checkout;
adjust both for another machine. Restart Claude Code after installing.
