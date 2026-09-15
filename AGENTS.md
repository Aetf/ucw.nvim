# AGENTS.md — working in `ucw.nvim`

The rules for changing this Neovim config, for agents and humans. Read this
first. The reference behind each rule is elsewhere: `docs/architecture.md`
is the code map, `docs/extending.md` the extension points (recipes, module
APIs, test helpers, tooling), `docs/features.md` and `docs/keys.md` what the
editor does and which key does it, `docs/testing.md` the suite's mechanics.
The reasoning behind a rule is in the design document it cites under
`docs/design/`.

## What this is

A personal Neovim config on **lazy.nvim**, one spec file per plugin under
`lua/ucw/plugins/`, with LSP on Neovim's native `vim.lsp.config` /
`vim.lsp.enable` layers. There is no plugin engine, no logger and no
framework of its own. Boot order is `docs/architecture.md` § Boot; the
`LspAttach` handler is installed before lazy.nvim on purpose. Context
predicates for spec `cond` are `lua/ucw/targets.lua`
(`is_gui/is_firenvim/is_vscode/is_full_ui`).

## Layout

- `lua/ucw/plugins/*.lua` — one lazy.nvim spec per plugin, including its keys.
- `lua/ucw/plugins/user/` — a same-named file here merges over the base spec
  (later import wins). Empty today.
- `lua/ucw/{options,builtin-plugins,keys,extras,targets,toggles,utils,git,health,gui}.lua`,
  `lua/ucw/keys/actions.lua`, `lua/ucw/neotree/`, `lua/ucw/textobjects/` —
  the config's own code.
- `lua/ucw/lsp/` — `servers.lua` (the server list), `init.lua`
  (enable/filetypes), `attach.lua` (`LspAttach`), `actions.lua`, `vscode.lua`,
  `ltex_dict.lua`, `texlab_sync.lua`, `utils.lua`.
- `after/lsp/<server>.lua` — per-server settings Neovim discovers itself.
- `ftplugin/<ft>.lua` — filetype options and `conform` formatters.
- `scripts/` — `keymap-snapshot.lua`, `keys-doc.lua`, `luarc-lint-config.lua`,
  `tui-drive.sh`.
- `tests/`, `docs/`, `justfile`, `mise.toml`, `.luarc.json`, `lazy-lock.json`.

## How to add or change a plugin

One file, `lua/ucw/plugins/<plugin>.lua`, returning a lazy.nvim spec. Start
from a neighbour (`gitsigns.lua` for an eager plugin with keys, `codediff.lua`
for a lazy one, `lspconfig.lua` for `ft`-triggered). Each of these fails
silently when wrong:

- **`keys =` makes the spec lazy.** A plugin that has to exist from startup
  (gutter, tabline, session autosave, formatter) needs an explicit
  `lazy = false` next to its keys, and a line in `tests/test_keys.lua`'s eager
  census (an explicit list; extend it when you add one).
- **`cond = require('ucw.targets').is_full_ui`** on anything with a UI surface
  of its own. A spec with `cond` false does not exist in lazy.nvim's plugin
  table at all, so code reaching into it from another spec must `pcall` or
  share the gate.
- **Order between eager specs is only guaranteed by `dependencies`.**
- **`opts` is a table, `config` is a function**; anything that has to run
  after `setup()` (Snacks.toggle registration, buffer-local overrides) goes in
  `config`.
- **`lazy-lock.json` is checked in and CI fails if it drifts.** Update through
  `:Lazy update`; never hand-edit. `:Lazy! install` does not downgrade an
  installed plugin; to A/B an older version, `git -C <plugin dir> checkout
  <sha>` or `:Lazy! restore`.
- **Keys go under the prefix `docs/design/phase9-keybindings.md` §5 assigns**,
  not the plugin's README defaults. A new namespace claims a free prefix, gets
  an eager group header in `which-key.lua` (lowercase label, explicit `icon`,
  `mode = { 'n', 'x' }`) and a row in the group census in
  `tests/test_keys.lua`. Then `just keys-doc`: `docs/keys.md`'s tables are
  generated and `tests/test_keys_doc.lua` fails while they are stale.

Removing a plugin: delete the spec, run `:Lazy clean`, commit the lockfile
change. `just lint` reads its library list from the lockfile, so a plugin
left on disk but out of the spec does not leak its globals into the lint.

## Key idioms

- **Autocmds** — `vim.api.nvim_create_autocmd` with a named, cleared
  `augroup`; no DSL. `BufModifiedSet` is gone in 0.13; use `OptionSet` with
  pattern `modified`.
- **Keys** — a plugin's keys live in *its own spec* as lazy.nvim
  `keys = { { lhs, rhs, desc = '...', silent = true }, ... }` entries;
  `lua/ucw/plugins/which-key.lua` keeps only group headers and core editor
  keys; toggles are `Snacks.toggle` objects (`lua/ucw/toggles.lua` for the
  editor's own, the plugin's spec for its own) so which-key shows live
  state, never a plain `<cmd>` rhs. Named actions in `keys/actions.lua`, LSP
  ones in `lua/ucw/lsp/actions.lua` as *paths* (so a renamed API fails a
  test instead of leaving a dead key).
- **A `desc` that looks like a rhs** (`{ lhs, desc = '<cmd>...<cr>' }`) is a
  key that does nothing and a popup entry that reads like code; in both
  `wk.add` and `keys =` the rhs is the second array element and a missing one
  is accepted silently. `tests/test_keys.lua` fails on it.
- **The keymap snapshot sees only global maps.** Anything registered on
  `LspAttach`, `FileType` or `BufWinEnter` is buffer-local and needs its own
  `nvim_buf_get_keymap` assertion, both halves (present where it should be,
  absent where it should not).
- **Previous/next is `[`/`]` + a category letter**, count-aware where native
  (`[d`, `[q`). `g` never means a direction; `g[`/`g]` are mini.ai's edge
  motions. `]]`/`[[` are not remapped.
- **`q` closes a read-only window**; `<Esc>` never does. Terminal-style
  windows close with the key that opened them
  (`docs/design/phase9.5-trial-period.md` §7.3).
- **Toggles are global unless the state is inherently per buffer.** The
  inlay-hint toggle drives the global flag and `attach.lua` mirrors it into
  each buffer (the per-buffer `Snacks.toggle.inlay_hints()` factory is the
  trap; `docs/extending.md` § `ucw.toggles`).
- **Options** — plain `vim.opt.*` in `options.lua`, commented with *why*.
  Take `vim.opt.X` into a `---@type vim.Option` local before `:append` so
  lua_ls does not infer the field's type from some plugin's assignment.
- **LSP** — use Neovim's native layers. To add a server: one line in
  `lua/ucw/lsp/servers.lua` (`name = { filetypes }`), which drives
  `vim.lsp.enable()`, Mason's `ensure_installed` and the lazy `ft` trigger at
  once; add `after/lsp/<name>.lua` only if it needs settings, and keep that
  file **table-only** (function fields replace nvim-lspconfig's outright
  instead of composing). Per-buffer behaviour goes in an `LspAttach` autocmd:
  `lua/ucw/lsp/attach.lua` for anything general, the plugin's own spec for
  anything server-specific. Nothing is eager and there is no enable key.
  `docs/design/phase3-lsp-redesign.md`.

  Invariants that break silently:
  - **A spec that starts a language server must `dependencies` on
    `mason.nvim`.** Mason's `setup()` puts the server binaries on `PATH`;
    without it the client never starts and nothing reports it.
  - **`ucw.lsp.vscode` is the only writer of `client.settings`.** Anything
    file-backed is a sidecar in that module, never a second writer
    (`docs/extending.md` § `ucw.lsp.vscode`,
    `docs/design/phase3-settings-composition.md`).
  - **A toggle and the thing it toggles must agree on scope.** Enabling a
    capability with a literal `true` at attach makes any toggle over it
    appear to need two presses and forget itself on the next file.
  - **Per-server capability edits go in `attach.lua`'s table**, not in
    `after/lsp/` (ruff's `hoverProvider` is declined there).
  - **`vim.lsp.config` merge semantics**: tables deep-merge, lists replace
    whole, a function field at the top level replaces the lower layer's.
- **Formatting** — `conform`; `formatters_by_ft` is set per filetype in
  `ftplugin/<ft>.lua`. A server that self-reports formatting but must not
  format (`lua_ls`, `texlab`) needs `lsp_format = 'never'` there, in every
  filetype the server attaches to. `docs/design/phase6-format-lint.md`.
- **Anything that runs a `BufWrite` or auto-installs at boot is gated on
  `is_full_ui`** (format-on-save, treesitter parser install);
  `#nvim_list_uis() > 0` alone is not the gate, embedded contexts attach a
  UI too.
- **Binaries resolve through `PATH`, Mason appended last.** `:checkhealth ucw`
  prints what each declared binary resolved to; a broken binary on `PATH`
  fails silently everywhere else.

## Testing

Harness is **mini.test**; `just unit` / `just int` / `just all` / `just ci`.
Run tests only through `just` or with `mise exec --` in front: the formatters
`tests/test_format.lua` drives are the versions `mise.toml` pins. Write tests
with `H.new_unit_test()` (pure modules) or `H.new_integration_test()` (the
booted config); the helper API and the child's traps are in
`docs/extending.md` § Testing and `docs/testing.md`.

A guard is not done until it has been reverse-verified: reinstate the bug it
covers and watch it go red.

Judge what the config draws, not only its logs: `docs/tui-observation.md`
(`child.get_screenshot()` in tests, `just tui …` ad hoc; asynchronous views
need a state poll before a capture).

## CI

`.github/workflows/ci.yml` only ever calls `just`, so reproducing CI is:

```sh
just ci          # the suite (matrix: neovim stable + nightly, nightly advisory)
just lint        # lua-language-server --check, gated on .luarc.json
just fmt-check   # stylua --check
git diff --exit-code lazy-lock.json   # after `just ci`: the lockfile did not drift
```

Three things that fail quietly when undone:

- `.luarc.json`'s `runtime.path` and `runtime.pathStrict` travel together
  (`tests/test_luarc.lua`); without `pathStrict`, `require('snacks')` resolves
  to this repo's own `snacks.lua` spec and the lint hides real findings.
- `just lint` errors rather than checking less when an input (`$VIMRUNTIME`,
  the plugin library, `deps/mini.nvim`) is missing. Do not remove the checks.
- `just test`/`plugins`/`lint`/`keys-doc` set `XDG_CONFIG_HOME` +
  `NVIM_APPNAME` so this checkout *is* the config Neovim loads; `rtp` is not
  a substitute. Simulating a runner needs a copy *and* an empty config
  directory (`docs/testing.md` § CI).

Suppressions are `---@diagnostic disable-next-line: <code>` with a comment
naming the evidence; the ones deliberately left are listed in
`docs/design/phase7-ci.md` §7.

## Conventions

- **Style**: stylua (`stylua.toml`), everywhere including `tests/`;
  `just fmt` writes, `just fmt-check` is the gate.
- **Comments and docs are as-built**: what the code does now and why, never
  what was tried. A new feature — including the debugger under `<leader>d`
  and AI integration under `<leader>a`, both reserved — lands as one ordinary
  change: spec, keys, tests, and the edits to this file,
  `docs/architecture.md`, `docs/features.md`, `docs/keys.md` and
  `docs/extending.md` together. Write a design document under `docs/design/`
  only when reopening a recorded decision.
- **No logger.** Use `vim.notify`; everything it emits is retrievable
  afterwards from `<leader>n`.
- **`VAR=x just …` does not reach the recipe** (the `just` wrapper is a zsh
  script that resets `XDG_*`); set variables on the actual process
  (`docs/testing.md` § CI).
- **Mason experiments use a scratch `XDG_DATA_HOME`**; never write into the
  real `~/.local/share/nvim` from a test.
- **After a Neovim upgrade, update nvim-treesitter and `:TSUpdate` together.**
  A query/runtime mismatch kills the async parse coroutine and every redraw
  errors until `:e!`.
