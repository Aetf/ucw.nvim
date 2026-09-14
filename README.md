# `ucw.nvim`

[![CI](https://github.com/Aetf/ucw.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/Aetf/ucw.nvim/actions/workflows/ci.yml)

My Neovim config: `lazy.nvim`, one spec file per plugin, LSP on Neovim's
native `vim.lsp.config`/`vim.lsp.enable` layers, and a test suite that boots
the whole thing headless.

- `AGENTS.md` — the rules for changing it (plugins, keys, LSP, CI).
- `docs/architecture.md` — the map: boot order, layout, what owns what.
- `docs/testing.md`, `docs/tui-observation.md` — the suite and how to look
  at the rendered TUI from outside.
- `docs/design/` — one design document and one independent acceptance
  review per phase of the 2026 modernization; the reasoning behind every
  decision above lives there.

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

## Notable pieces

- Workspace LSP settings from `.vscode/settings.json`, including ltex
  dictionaries, rebuilt on every change (`lua/ucw/lsp/vscode.lua`).
- Keys follow native vocabulary first (`gr*` for LSP, `[`/`]` + letter for
  previous/next), then LazyVim's `<leader>` namespaces; the placement rule
  for a new plugin is a table in `docs/design/phase9-keybindings.md` §5.
- The neogit ↔ codediff seam (`lua/ucw/git.lua`): `<CR>` on any commit opens
  it in codediff; `<leader>gm` shows the commit message from either side.
