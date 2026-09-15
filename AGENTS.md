# AGENTS.md — working in `ucw.nvim`

Guidance for AI agents (and humans) editing this Neovim config. Read this first.
`docs/architecture.md` is the map of the code; this file is the rules for
changing it. The reasoning behind a rule is in the phase design document it
cites under `docs/design/`.

## What this is

A personal Neovim config on **`lazy.nvim`**, one spec file per plugin under
`lua/ucw/plugins/`, with LSP on Neovim's native `vim.lsp.config` /
`vim.lsp.enable` layers. There is no plugin engine, no logger and no framework
of its own; the config's own code is options, keys, and the seams between
plugins that no plugin owns (`lua/ucw/git.lua`, `lua/ucw/lsp/attach.lua`, …).

Boot: `init.lua` → `require('ucw').boot()` (`lua/ucw/init.lua`) loads the
plugin-free modules (`options`, `builtin-plugins`, `keys`, `extras`), installs
the `LspAttach` handler, bootstraps lazy.nvim at the commit `lazy-lock.json`
pins, and imports `ucw.plugins` then `ucw.plugins.user`. Context predicates for
spec `cond` live in `lua/ucw/targets.lua` (`is_gui/is_firenvim/is_vscode/
is_full_ui`).

## Layout

- `lua/ucw/plugins/*.lua` — one lazy.nvim spec per plugin, including its keys.
- `lua/ucw/plugins/user/` — a same-named file here merges over the base spec
  (lazy.nvim merges specs per plugin, later import wins). Empty today.
- `lua/ucw/{options,keys,extras,toggles,utils,git,health,gui}.lua`,
  `lua/ucw/keys/actions.lua` — the config's own code.
- `lua/ucw/lsp/` — `servers.lua` (the server list), `init.lua`
  (enable/filetypes), `attach.lua` (`LspAttach`), `actions.lua`, `vscode.lua`,
  `ltex_dict.lua`, `texlab_sync.lua`, `utils.lua`.
- `after/lsp/<server>.lua` — per-server settings Neovim discovers itself.
- `ftplugin/<ft>.lua` — filetype options and `conform` formatters.
- `scripts/` — `keymap-snapshot.lua`, `luarc-lint-config.lua`, `tui-drive.sh`.
- `tests/`, `docs/`, `justfile`, `mise.toml`, `.luarc.json`, `lazy-lock.json`.

## How to add or change a plugin

One file, `lua/ucw/plugins/<plugin>.lua`, returning a lazy.nvim spec. Start
from a neighbour (`gitsigns.lua` for an eager plugin with keys, `codediff.lua`
for a lazy one, `lspconfig.lua` for `ft`-triggered). What the spec must get
right, each of which fails silently:

- **`keys =` makes the spec lazy.** A plugin that has to exist from startup
  (gutter, tabline, session autosave, formatter) needs an explicit
  `lazy = false` next to its keys, and a line in `tests/test_keys.lua`'s eager
  census (the census is an explicit list; extend it when you add one).
- **`cond = require('ucw.targets').is_full_ui`** on anything with a UI surface
  of its own. A spec with `cond` false does not exist in lazy.nvim's plugin
  table at all — its keys are not registered, `require`ing it errors — so code
  reaching into it from another spec must `pcall` or gate the same way.
- **Order between eager specs is only guaranteed by `dependencies`.** Two
  `lazy = false` specs load in an order you do not control.
- **`opts` is a table, `config` is a function**; anything that has to run
  after `setup()` (Snacks.toggle registration, buffer-local overrides) goes in
  `config`.
- **`lazy-lock.json` is checked in and CI fails if it drifts.** Update through
  `:Lazy update`; never hand-edit. `:Lazy! install` does not downgrade an
  installed plugin — to A/B an older version, `git -C <plugin dir> checkout
  <sha>` or `:Lazy! restore`.
- **Keys go under the prefix `docs/design/phase9-keybindings.md` §5 assigns**,
  not the plugin's README defaults. A new namespace claims a free prefix, gets
  an eager group header in `which-key.lua` (lowercase label, explicit `icon`,
  `mode = { 'n', 'x' }`) and a row in the group census in
  `tests/test_keys.lua`.

Removing a plugin: delete the spec, run `:Lazy clean`, commit the lockfile
change. `just lint` reads its library list from the lockfile, so a plugin
left on disk but out of the spec no longer leaks its globals into the lint.

## Key idioms

- **Autocmds** — `vim.api.nvim_create_autocmd` with a named, cleared
  `augroup`; no DSL. `BufModifiedSet` is gone in 0.13; use `OptionSet` with
  pattern `modified`.
- **Keymaps** — a plugin's keys live in *its own spec* as lazy.nvim
  `keys = { { lhs, rhs, desc = '...', silent = true }, ... }` entries;
  `lua/ucw/plugins/which-key.lua` keeps only group headers and core editor
  keys; toggles are `Snacks.toggle` objects (`lua/ucw/toggles.lua` for the
  editor's own, the plugin's spec for its own) so which-key shows live
  state — never a plain `<cmd>` rhs. Named actions in `keys/actions.lua`, LSP
  ones in `lua/ucw/lsp/actions.lua` as *paths* (so a renamed API fails a
  test instead of leaving a dead key); low-level remaps via
  `require('ucw.utils').map` in `keys.lua`.
  **Two traps.** ① In both `wk.add` and `keys =` the rhs is the *second
  array element*; an entry with no rhs is accepted silently, so
  `{ lhs, desc = '<cmd>...<cr>' }` is a key that does nothing and a popup
  entry that reads like code; `tests/test_keys.lua` fails on any `desc` that
  looks like a rhs, in any mechanism. ② The global keymap snapshot
  (`scripts/keymap-snapshot.lua`) sees only global maps; anything registered
  on `LspAttach`, `FileType` or `BufWinEnter` (`[r`/`]r`, `[h`/`]h`, neogit's
  `<CR>`, help/quickfix `q`) is buffer-local and needs its own
  `nvim_buf_get_keymap` assertion, both halves (present where it should be,
  absent where it should not).
- **Previous/next is `[`/`]` + a category letter**, count-aware where native
  (`[d`, `[q`). `g` never means a direction; `g[`/`g]` are mini.ai's edge
  motions. `]]`/`[[` are not remapped (native section motions).
- **`q` closes a read-only window**; `<Esc>` never does (it clears
  highlight/notifications and cancels input UIs). Terminal-style windows close
  with the key that opened them. `docs/design/phase9.5-trial-period.md` §7.3.
- **Toggles are global unless the state is inherently per buffer.**
  `Snacks.toggle.inlay_hints()` is per-buffer (`bufnr = 0`); the config's own
  `toggles.lua` entry drives the global flag and `attach.lua` mirrors it into
  each buffer. `Snacks.toggle.get(id)` returns a factory for unknown ids, so a
  census over the registry must `rawget`.
- **Options** — plain `vim.opt.*` in `options.lua`, heavily commented with
  *why*. Take `vim.opt.X` into a `---@type vim.Option` local before `:append`
  so lua_ls does not infer the field's type from some plugin's assignment.
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

  Invariants that are easy to break silently, most of them first found by an
  acceptance review:
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
  - **`vim.lsp.buf.hover` asks every client that declares hover and reports
    each empty answer.** A server that declares it but returns nothing
    (ruff) gets `hoverProvider` cleared at attach, in `attach.lua`'s
    per-server table — not by editing `after/lsp/`.
  - **`vim.lsp.config` merge semantics**: tables deep-merge, lists replace
    whole, a function field at the top level replaces the lower layer's.
- **Formatting** — `conform`; `formatters_by_ft` is set per filetype in
  `ftplugin/<ft>.lua`. A server that self-reports formatting but must not
  format (`lua_ls`, `texlab`) needs `lsp_format = 'never'` there.
  `docs/design/phase6-format-lint.md`.
- **Anything that runs a `BufWrite` or auto-installs at boot is gated on
  `is_full_ui`** (format-on-save, treesitter parser install): under firenvim
  a write is the push back to the page, and embedded contexts attach a UI
  too, so `#nvim_list_uis() > 0` alone is not the gate.
- **Binaries resolve through `PATH`, Mason appended last.** The project's
  toolchain wins; `:checkhealth ucw` prints what each declared binary
  resolved to. A broken binary on `PATH` fails silently everywhere else.

## Testing

Harness is **mini.test** (fetched into `deps/`, gitignored — a test-only
copy, separate from the mini.nvim lazy.nvim manages at runtime). Recipes
(`justfile`):

```sh
just deps      # pinned binaries (mise.toml) + mini.nvim into deps/, at lazy-lock.json's commit
just unit      # unit tests   (tag: unit)
just int       # integration tests (tag: integration; full config boot + install)
just all       # everything
just ci        # everything, do not stop on error
```

Run tests only through `just` or with `mise exec --` in front: the formatters
`tests/test_format.lua` drives are the versions `mise.toml` pins, and without
them a third of that file goes red for reasons unrelated to your change.

Two-stage model: a headless *driver* nvim runs each `tests/test_*.lua`; each test
spawns a clean *child* nvim per case. Write tests with `H.new_unit_test()` (cwd
+ mini.test only) or `H.new_integration_test()` (full config). See
`docs/testing.md` for the child's traps (feedkeys, hit-enter, noice routing).

A guard is not done until it has been reverse-verified: reinstate the bug it
covers and watch it go red. Every acceptance review so far has found at least
one instrument that stops exactly where the phase's attention stopped.

## CI

`.github/workflows/ci.yml` runs on every push and pull request, and it only ever
calls `just` — the gates are recipes, so "reproduce CI locally" is one line:

```sh
just ci          # the suite (matrix: neovim stable + nightly, nightly advisory)
just lint        # lua-language-server --check, gated on .luarc.json
just fmt-check   # stylua --check
git diff --exit-code lazy-lock.json   # after `just ci`: the lockfile did not drift
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
  (enumerated from `lazy-lock.json`, so a plugin left on disk after removal
  is not a library) and `deps/mini.nvim`, and **errors** rather than checking
  less if it cannot. A locked plugin that is not installed is *not* an error
  (`cond`-gated plugins are locked but never installed in CI). Don't
  "simplify" any of them away. Isolating a lint finding means whole-repo
  `--check .` with `VIMRUNTIME` exported; a single-file check has a different
  workspace and hides it.
- `just test`/`just plugins`/`just lint` set `XDG_CONFIG_HOME` + `NVIM_APPNAME`
  so this checkout *is* the config directory Neovim loads. On this machine that
  is a no-op (the repo already is `~/.config/nvim`); on a runner it is the whole
  difference between working and not. **`rtp` is not a substitute** — lazy.nvim
  resets `rtp` to `stdpath('config')` before importing specs, which is why the
  integration suite needs this too even though the harness puts `getcwd()` on
  the child's `rtp` explicitly. Simulating a runner means copying the tree *out
  of* `~/.config` **and** giving it an empty `XDG_CONFIG_HOME`; the copy alone
  still falls back to your real `~/.config/nvim` and passes.

Reproducing the lockfile-drift gate locally:

```sh
MISE_DATA_DIR=$HOME/.local/share/mise XDG_DATA_HOME=/tmp/scratch XDG_CONFIG_HOME=~/.config NVIM_APPNAME=nvim \
  mise exec -- nvim --headless '+Lazy! install' +qa && git diff --exit-code lazy-lock.json
```

`MISE_DATA_DIR` must be pinned alongside `XDG_DATA_HOME`, or mise's own
plugin directory moves with it and mise errors.

Suppressions are `---@diagnostic disable-next-line: <code>` with a comment
naming the evidence; the ones deliberately left are listed in
`docs/design/phase7-ci.md` §7.

## Observing the rendered TUI

You can inspect what the config *actually draws* (screen text, colors, floats,
cursor) — not just logs. Three tiers, detailed in **`docs/tui-observation.md`**:

- **Tests**: `child.get_screenshot()` in mini.test (see `tests/test_tui_screenshot.lua`).
- **Ad-hoc**: `scripts/tui-drive.sh` drives a real nvim in a detached tmux session
  and reads the screen back (`start` / `send` / `cmd` / `capture` / `messages` / …).
  Start and stop it from `/tmp` (an auto-session suppressed dir), or stopping
  overwrites the session saved for this repo.
- **Reference**: `vim.api.nvim__screenshot(path)` (internal; underlies the above).

Asynchronous views (codediff, neogit) are not on screen the moment the command
returns: judge by state read over RPC (`codediff.ui.lifecycle.get_session`,
neogit's real content rather than its 4-line skeleton), then `redraw!` and
capture.

## Conventions & gotchas

- **Style**: stylua (`stylua.toml`: 2-space indent, single quotes, `NoSingleTable`),
  everywhere including `tests/` (`.git-blame-ignore-revs` hides the one-shot
  reformat). `just fmt` writes, `just fmt-check` is the gate. If you are
  editing by hand rather than through Neovim's `format_on_save`, run
  `just fmt` before committing.
- **Comments and design docs are as-built**: what the code does now and why,
  not what was tried. A phase document is the record of its own phase; when
  a later phase supersedes it, the earlier document says so inline and points
  forward, and this file plus `docs/architecture.md` describe the present.
- **No logger.** Use `vim.notify`; everything it emits is retrievable
  afterwards from `<leader>n` (noice history).
- **`VAR=x just …` does not reach the recipe.** `just` here is a zinit wrapper
  with a `#!/usr/bin/env zsh` shebang, and zsh's own startup reassigns the `XDG_*`
  variables on the way through — so `XDG_DATA_HOME=/tmp/scratch just lint` runs
  against your real plugin directory and looks like it worked. To exercise a
  recipe against a scratch environment, run its commands directly with the
  variable set on the actual process.
- **Mason experiments use a scratch `XDG_DATA_HOME`**; never write into the
  real `~/.local/share/nvim` from a test.
- **After a Neovim upgrade, update nvim-treesitter and `:TSUpdate` together.**
  A query/runtime mismatch kills the async parse coroutine and every redraw
  errors until `:e!`.
