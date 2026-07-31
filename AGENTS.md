# AGENTS.md — working in `ucw.nvim`

Guidance for AI agents (and humans) editing this Neovim config. Read this first.

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
  (`units/thirdparty/which-key.lua`) via `wk.add {...}`; named actions in
  `keys/actions.lua`.
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
just deps      # clone/update mini.nvim into deps/mini.nvim
just unit      # unit tests   (tag: unit)
just int       # integration tests (tag: integration; full config boot + install)
just all       # everything
just ci        # everything, do not stop on error
```

Two-stage model: a headless *driver* nvim runs each `tests/test_*.lua`; each test
spawns a clean *child* nvim per case. Write tests with `H.new_unit_test()` (no
nvimd) or `H.new_integration_test()` (full config). See `docs/testing.md`.

## Observing the rendered TUI

You can inspect what the config *actually draws* (screen text, colors, floats,
cursor) — not just logs. Three tiers, detailed in **`docs/tui-observation.md`**:

- **Tests**: `child.get_screenshot()` in mini.test (see `tests/test_tui_screenshot.lua`).
- **Ad-hoc**: `scripts/tui-drive.sh` drives a real nvim in a detached tmux session
  and reads the screen back (`start` / `send` / `cmd` / `capture` / `messages` / …).
- **Reference**: `vim.api.nvim__screenshot(path)` (internal; underlies the above).

## Conventions & gotchas

- **Style**: stylua (`stylua.toml`: 2-space indent, single quotes, `NoSingleTable`).
  Note `lua/**` uses 2-space, but existing files under `tests/` use 4-space — match
  the file you are editing.
- **Two loggers**: `ucw` uses structlog (`ucw/log.lua`; TRACE → `./test.log`);
  `nvimd` uses a vlog-derived logger (`nvimd/utils/log.lua`; → `stdpath('data')/nvimd.log`,
  default level `warn`). Anything in `nvimd.log` is already noteworthy.
- **No CI** yet (the `just ci` recipe exists but nothing runs it).
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
