# AGENTS.md — working in `ucw.nvim`

Guidance for AI agents (and humans) editing this Neovim config. Read this first.

> **Stale sections, deliberately.** The `nvimd` engine described below (units,
> targets, `nvimctl`, paq-nvim, compiled targets) **no longer exists** — Phase 1
> of the modernization replaced all of it with `lazy.nvim` specs under
> `lua/ucw/plugins/`, and `lua/nvimd/` and `lua/ucw/units/` are deleted. The
> rewrite of "Architecture map", "How to add or change a plugin", "Runtime
> handles" and `docs/architecture.md` is Phase 10's job, so it is not being done
> piecemeal. Until then: **"Key idioms" and everything from "Testing" down are
> current**; treat "What this is" through "How to add or change a plugin" as
> history. Ground truth is `lua/ucw/plugins/*.lua` and the phase design
> documents in `docs/design/`.

## What this is

`ucw.nvim` is a personal Neovim config built on a **systemd-inspired plugin/unit
engine**. There are two Lua namespaces under `lua/`:

- **`nvimd/`** — the engine (generic, no personal config). Plugins are declared as
  *units* with systemd-style dependencies (`requires`/`wants`/`before`/`after`/…);
  a resolver + transaction layer topologically orders and activates them. Think
  "systemd for Neovim". `nvimctl` is the "systemctl".
- **`ucw/`** — the actual personal config: options, keymaps, LSP framework, and the
  unit definitions for every plugin.

Boot flow: `init.lua` → `require('ucw').boot()` (`lua/ucw/init.lua`) loads eager
config (`options`, `builtin-plugins`, `keys`, `extras`), picks a target
(`target.gui` / `target.firenvim` / `target.tui`), then calls
`require('nvimd').boot({ units_modules = { 'ucw.units.thirdparty', 'ucw.units.user' } }, target)`.

For a deeper mental model of the engine, read `docs/architecture.md`.

## Architecture map

Engine (`lua/nvimd/`):
- `init.lua` — `boot()`; tries the compiled target first, falls back to full build.
- `boot.lua` — bootstraps the paq-nvim install backend.
- `resolver.lua` — discovers/loads/**merges** unit definitions across module roots.
- `txn.lua` — topological sort with refcounting + cycle detection.
- `nvimctl.lua` (+ `nvimctl/compile.lua`) — activate/start/enable/status/sync/compile/graph.
- `trigger.lua` — `activation.cmd` lazy-load stubs.
- `utils.lua`, `utils/log.lua` — helpers + the `nvimd` logger.

Personal config (`lua/ucw/`):
- `init.lua`, `options.lua`, `keys.lua`, `keys/actions.lua`, `extras.lua`,
  `builtin-plugins.lua`, `utils.lua`, `log.lua`.
- `units/thirdparty/*.lua` — one file per plugin (the base layer).
- `units/user/*.lua` — user overrides; a file with the **same unit name** merges over
  the thirdparty one (later roots win).
- `lsp/` — LSP wiring: `servers.lua` (the server list), `init.lua`
  (enable/filetypes), `attach.lua` (`LspAttach` handlers), `actions.lua`,
  `vscode.lua`, plus per-server helper modules. Per-server *config* lives in
  the repo's top-level `after/lsp/<server>.lua`, which Neovim discovers itself.
- `lua/au.lua` — the autocmd DSL.
- `ftplugin/` — standard filetype configs.

## How to add or change a plugin

Create/edit one unit file, usually `lua/ucw/units/thirdparty/<plugin>.lua`. The
**file stem == unit name == packadd name**, so name it after the plugin (hyphens ok).
Return a table `M`:

```lua
local M = {}
M.url = 'author/plugin.nvim'          -- installed as an `opt` package by paq
M.description = 'what it does'
M.wants = { 'some-dep' }              -- systemd-style deps: requires/wants/requisite/before/after
M.activation = {
  wanted_by = { 'target.basic' },     -- pulled in when this target starts
  -- cmd = 'PluginCmd',               -- OR: lazy-load on first use of :PluginCmd
}
function M.setup() end                 -- runs before packadd
function M.config()                    -- runs after packadd
  require('plugin').setup {}
end
return M
```

Good templates to copy: `units/thirdparty/{telescope,nvim-cmp,treesitter,which-key}.lua`.
Targets live in `lua/nvimd/units/target/*.lua`. To override a thirdparty unit, add a
same-named file under `units/user/`.

Activation sequence per unit: `setup()` → `packadd` → source its `after/` files →
`config()`. Everything is `pcall`-wrapped with structured logging.

## Key idioms

- **Autocmds** — use the `au` DSL (`lua/au.lua`): `au.BufWritePost = fn` or
  `au.group('Name', { BufEnter = fn, ... })`. Raw `nvim_create_autocmd` also appears.
- **Keymaps** — global maps via `require('ucw.utils').map(modes, lhs, rhs, opts)`
  (defaults `noremap=true`); the bulk of leader bindings live in which-key
  (`lua/ucw/plugins/which-key.lua`) via `wk.add {...}`; named actions in
  `keys/actions.lua`, and LSP ones in `lua/ucw/lsp/actions.lua`.
  **which-key v3 trap**: the rhs is the *second array element*,
  `{ lhs, rhs, desc = '...' }`. An entry with no rhs is accepted silently — it
  registers a label for a key nobody mapped — so `{ lhs, desc = '<cmd>...<cr>' }`
  (the shape the v2 → v3 conversion produced) is a key that does nothing and a
  popup entry that reads like code. `g[`/`g]` were dead that way for a month;
  `tests/test_keys.lua` now fails on any `desc` that looks like a rhs.
- **Options** — plain `vim.opt.*` in `options.lua`, heavily commented with *why*.
- **LSP** — there is no framework to learn; use Neovim's native layers.
  To add a server: one line in `lua/ucw/lsp/servers.lua` (`name = { filetypes }`),
  which drives `vim.lsp.enable()`, Mason's `ensure_installed` and the lazy `ft`
  trigger at once; add `after/lsp/<name>.lua` only if it needs settings, and
  keep that file **table-only** (function fields replace nvim-lspconfig's
  outright instead of composing). Per-buffer behaviour goes in an `LspAttach`
  autocmd — `lua/ucw/lsp/attach.lua` for anything general, or the plugin's own
  spec for anything server-specific. LSP starts by itself on the filetype of a
  supported buffer; nothing is eager and there is no enable keybinding.
  See `docs/design/phase3-lsp-redesign.md`.

  Three invariants that are easy to break silently, each one an acceptance
  review finding (`docs/design/phase3-acceptance-review.md`):
  - **A spec that starts a language server must `dependencies` on
    `mason.nvim`.** Mason's `setup()` is what puts the server binaries on
    `PATH`; without it a client simply never starts, and says so nowhere —
    not in `:messages`, not in `lsp.log`.
  - **`ucw.lsp.vscode` is the only writer of `client.settings`.** It rebuilds
    them from an attach-time snapshot on every `.vscode/` change, so a second
    writer is silently overwritten. Anything file-backed belongs in that
    module's `SIDECAR_KEYS` instead: `<dir>/<key>.<variant>.txt` is unioned into
    `settings[<key>][<variant>]`, which is how the ltex dictionaries work.
    `ucw.lsp.ltex_dict` writes those files and calls `vscode.reload()`; it never
    touches `client.settings`. See
    `docs/design/phase3-settings-composition.md`.
  - **A toggle and the thing it toggles must agree on scope.**
    `vim.lsp.inlay_hint`'s global flag is the user preference; `attach.lua`
    mirrors it per buffer. Enabling a capability with a literal `true` at
    attach makes any toggle over it appear to need two presses and forget
    itself on the next file.

## Runtime handles (interactive debugging)

`_G.nvimctl` is a live global once past `VimEnter`:
- `:lua nvimctl:status()` — systemctl-like unit status.
- `:lua nvimctl:start('target.lsp')` — activate a unit/target now.
- `:lua nvimctl:reload()` — reload units without restarting.
- `:lua nvimctl:sync()` — install plugins + recompile.
- `:lua nvimctl:graph('/tmp/units.dot')` — dump the dependency graph (graphviz).

## Testing

Harness is **mini.test** (fetched into `deps/`, gitignored). Recipes (`justfile`):

```sh
just deps      # pinned binaries (mise.toml) + mini.nvim into deps/, at lazy-lock.json's commit
just unit      # unit tests   (tag: unit)
just int       # integration tests (tag: integration; full config boot + install)
just all       # everything
just ci        # everything, do not stop on error
```

Two-stage model: a headless *driver* nvim runs each `tests/test_*.lua`; each test
spawns a clean *child* nvim per case. Write tests with `H.new_unit_test()` (no
nvimd) or `H.new_integration_test()` (full config). See `docs/testing.md`.

## CI

`.github/workflows/ci.yml` runs on every push and pull request, and it only ever
calls `just` — the three gates are recipes, so "reproduce CI locally" is one line:

```sh
just ci          # the suite (matrix: neovim stable + nightly, nightly advisory)
just lint        # lua-language-server --check, gated on .luarc.json
just fmt-check   # stylua --check
```

Two things about `just lint` that are easy to undo by accident, because both
fail *quietly* — a weaker lua_ls config looks exactly like a working one:

- `.luarc.json` is **checked in** so the editor applies the same rules while you
  type (that is the whole reason it is not generated). Its `runtime.path` and
  `runtime.pathStrict` travel together: an explicit `path` carrying `lua/?.lua`
  without `pathStrict` makes `require('snacks')` resolve to this repo's own
  `lua/ucw/plugins/snacks.lua`, which drops three real findings and invents a
  false one. `tests/test_luarc.lua` asserts they stay together, and that the
  globals here cover `after/lsp/lua_ls.lua`'s.
- The recipe supplies `$VIMRUNTIME`, the installed plugins' `lua/` directories
  and `deps/mini.nvim`, and **errors** rather than checking less if it cannot.
  Don't "simplify" any of them away.
- `just test`/`just plugins`/`just lint` set `XDG_CONFIG_HOME` + `NVIM_APPNAME`
  so this checkout *is* the config directory Neovim loads. On this machine that
  is a no-op (the repo already is `~/.config/nvim`); on a runner it is the whole
  difference between working and not. **`rtp` is not a substitute** — lazy.nvim
  resets `rtp` to `stdpath('config')` before importing specs, which is why the
  integration suite needs this too even though the harness puts `getcwd()` on
  the child's `rtp` explicitly. Simulating a runner means copying the tree *out
  of* `~/.config` **and** giving it an empty `XDG_CONFIG_HOME`; the copy alone
  still falls back to your real `~/.config/nvim` and passes.

Suppressions are `---@diagnostic disable-next-line: <code>` with a comment
naming the evidence; the ones deliberately left are listed in
`docs/design/phase7-ci.md` §7.

## Observing the rendered TUI

You can inspect what the config *actually draws* (screen text, colors, floats,
cursor) — not just logs. Three tiers, detailed in **`docs/tui-observation.md`**:

- **Tests**: `child.get_screenshot()` in mini.test (see `tests/test_tui_screenshot.lua`).
- **Ad-hoc**: `scripts/tui-drive.sh` drives a real nvim in a detached tmux session
  and reads the screen back (`start` / `send` / `cmd` / `capture` / `messages` / …).
- **Reference**: `vim.api.nvim__screenshot(path)` (internal; underlies the above).

## Conventions & gotchas

- **Style**: stylua (`stylua.toml`: 2-space indent, single quotes, `NoSingleTable`),
  everywhere including `tests/` — Phase 7 applied it to the whole repo in one commit
  (`.git-blame-ignore-revs`), so there is no per-directory convention to match any
  more. `just fmt` writes, `just fmt-check` is the gate. If you are editing by hand
  rather than through Neovim's `format_on_save`, run `just fmt` before committing.
- **No logger**: there used to be two (a structlog-backed `ucw/log.lua`, and `nvimd`'s
  vlog-derived one). Both are gone — `nvimd` with Phase 1, structlog with Phase 5,
  which found `ucw.log` had never had a single caller. Use `vim.notify`; everything
  it emits is retrievable afterwards from `:Noice` / `<leader>nn`.
- **CI runs the suite, the linter and the formatter** on every push and PR — see
  the "CI" section above. `just ci` / `just lint` / `just fmt-check` locally are
  the same gates, not approximations of them.
- **`VAR=x just …` does not reach the recipe.** `just` here is a zinit wrapper
  with a `#!/usr/bin/env zsh` shebang, and zsh's own startup reassigns the `XDG_*`
  variables on the way through — so `XDG_DATA_HOME=/tmp/scratch just lint` runs
  against your real plugin directory and looks like it worked. To exercise a
  recipe against a scratch environment, run its commands directly with the
  variable set on the actual process.
- **Fast boot**: startup uses a *compiled* target; `_G.nvimctl` is rebuilt lazily on
  `VimEnter`. If you change unit graphs, a recompile (`nvimctl:sync()` / next boot)
  is needed to take effect.
- **Don't mirror existing typos** when editing near them, e.g. `vim.log.lvels`
  (`lua/ucw/utils.lua`, should be `levels`) and `nvim_win_set_curosr`
  (`ftplugin/tex.lua`).

## Known issues

- **treesitter `latex` parser needs the `tree-sitter` CLI**, which is not installed
  → nvim prints an error during `init.lua` on every boot (a hit-enter prompt). Fix
  is either installing the `tree-sitter` CLI or dropping `latex` from
  `ensure_installed` in `units/thirdparty/treesitter.lua`. See
  `docs/tui-observation.md` for how this was found.
