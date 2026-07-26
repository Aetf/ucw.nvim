# Architecture: `nvimd`, the systemd-for-Neovim engine

This config models plugins as **systemd-style units**. Instead of a flat plugin list,
each plugin declares dependencies and ordering, and an engine (`nvimd`) resolves,
orders, and activates them. This doc explains how that engine works so you can reason
about load order and lazy-loading. For day-to-day "how do I add a plugin", see
`../AGENTS.md`.

## Layers

- **`lua/nvimd/`** — the engine. Generic, reusable, no personal config.
- **`lua/ucw/`** — the personal config, including all unit *definitions*.
- **paq-nvim** — the install backend. Every unit with a `url` becomes an `opt`
  package; the engine never auto-loads, it `packadd`s on activation.

## Units

A unit is a Lua module returning a table `M`. Fields (semantics mirror
[systemd.unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)):

- Identity/install: `url`, `description`, `run` (build cmd).
- Ordering & deps: `requires`, `wants`, `requisite`, `before`, `after`.
- Install-section analog: `activation.wanted_by`, `activation.required_by`,
  `activation.requisite_of`, and `activation.cmd` (lazy-load on a command).
- `no_default_dependencies` to opt out of implicit edges.
- Lifecycle: `setup()` (pre-`packadd`) and `config()` (post-`packadd`).

Default dependencies (unless `no_default_dependencies`): every target gains `after` on
all of its `wants`/`requires`/`requisite`; every unit gains `after` on `target.base`.

**Targets** are units named `target.*` (in a `target/` subdir), used as grouping/sync
points like systemd targets. Hierarchy: `target.tui` → `target.basic` →
(`target.mapping`, `target.completion`), everything after `target.base`.

## Unit discovery and merging (`resolver.lua`)

Units are found by scanning the configured `units_modules` roots plus the built-in
`nvimd.units`. A unit *name* is resolved across **all** roots and the tables are
**merged**, later roots overriding earlier ones. This is why
`ucw/units/user/<name>.lua` can extend/override a `ucw/units/thirdparty/<name>.lua`
of the same name — intentional layering.

## Ordering and activation (`txn.lua`, `nvimctl.lua`)

`txn.lua` performs a real topological sort: a DFS builds a graph with reference counts
for strong (`wants`/`requires`) vs weak (`requisite`) holds, prunes disabled/unheld
units, then activates Kahn-style along `before`/`after` edges. Cycles are warned, not
fatal.

Per-unit **activation sequence** (`nvimctl._activate`), each step `pcall`-wrapped with
structured logging:

1. clear the unit's lazy triggers,
2. lazily `require` its config source (for `config`/`setup`),
3. run `unit.setup()`,
4. `packadd` the plugin,
5. source its `after/` files (if past `VimEnter`),
6. run `unit.config()`.

## Lazy-loading

Nothing auto-loads. A unit activates when something that holds it
(`wanted_by`/`required_by`) starts — targets are the top-level entry points.
`activation.cmd` (`trigger.lua`) creates a stub command that, on first use, starts the
unit and re-runs the real command. `target.lsp` is deferred entirely and started on
demand (`<leader>ll`), so editing starts fast and LSP is opt-in per session.

## Fast boot: compiled targets (`nvimctl/compile.lua`)

`nvimd.boot()` first tries to `require` a **compiled** target file
(`stdpath('data')/site/lua/nvimd/compiled/<target>.lua`) and call it. That generated
file directly calls `_activate({...})` for each unit in topological order (with
profiling hooks) — no resolver/txn work at startup. It also registers a `VimEnter`
autocmd that lazily rebuilds a full `nvimctl` instance into `_G.nvimctl`, so runtime
introspection/commands still work while startup stays cheap.

Only if the compiled file is missing/broken does `boot()` build a full `nvimctl` and
run `sync → compile → start`.

Implication: **changes to the unit graph need a recompile to take effect.** Trigger it
with `:lua nvimctl:sync()` (installs + recompiles) or rely on the fallback on next
boot. `nvimctl:reload()` reloads unit modules without restarting nvim.

## Introspection

`_G.nvimctl` (systemctl analog): `:status()`, `:start(name)`, `:enable()`/`:disable()`,
`:reload()`, `:sync()`, and `:graph(path)` which emits a graphviz dependency graph —
useful when ordering isn't what you expect.

## Extra layers built on top

- **`lua/au.lua`** — an autocmd DSL (`au.Event = fn`, `au.group(...)`).
- **`lua/ucw/lsp/`** — a centralized LSP hook framework: register
  `on_server_setup` / `on_new_config` / `on_attach` hooks (pattern-filtered), plus
  per-server modules `ucw/lsp/lang/<server>.lua`. lspconfig's `default_config` /
  `on_setup` are monkey-patched to fan out to these.
- **VSCode compat** (`ucw/lsp/vscode.lua`) — loads `.vscode/settings.json` and ltex
  dictionaries for workspace-specific LSP settings.

## File index

Engine: `lua/nvimd/{init,boot,nvimctl,resolver,trigger,txn,utils}.lua`,
`lua/nvimd/nvimctl/compile.lua`, `lua/nvimd/utils/log.lua`,
`lua/nvimd/units/target/*.lua`.

Config: `lua/ucw/{init,options,keys,extras,builtin-plugins,utils,log}.lua`,
`lua/ucw/keys/actions.lua`, `lua/au.lua`, `lua/ucw/lsp/*`,
`lua/ucw/units/{thirdparty,user}/*.lua`, `ftplugin/*`.
