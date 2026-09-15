# `ucw.nvim`

[![CI](https://github.com/Aetf/ucw.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/Aetf/ucw.nvim/actions/workflows/ci.yml)

My Neovim config: `lazy.nvim`, one spec file per plugin, LSP on Neovim's
native `vim.lsp.config`/`vim.lsp.enable` layers, and a test suite that boots
the whole thing headless.

- `docs/features.md` — what it does for you; `docs/keys.md` — every key.
- `AGENTS.md` — the rules for changing it (plugins, keys, LSP, CI);
  `docs/extending.md` — the extension points, module APIs and tooling.
- `docs/architecture.md` — the map: boot order, layout, what owns what.
- `docs/testing.md`, `docs/tui-observation.md` — the suite and how to look
  at the rendered TUI from outside.
- `docs/design/` — the design document and, for most phases, the
  independent acceptance review of each phase of the 2026 modernization
  (complete; the table in `docs/architecture.md` lists them). The reasoning
  behind every decision above lives there.

## Working on it

```sh
just deps       # pinned binaries (mise.toml) + a test-only mini.nvim into deps/
just ci         # the suite, as CI runs it
just lint       # lua-language-server --check
just fmt-check  # stylua
```

`mise.toml` pins the binaries the repo needs to work on itself; Neovim finds
the same ones through `PATH`, with Mason's copies as the fallback, and
`:checkhealth ucw` prints which one won.
