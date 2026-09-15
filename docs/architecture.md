# Architecture

`ucw.nvim` is a personal Neovim config on `lazy.nvim`. There is no engine of
its own: plugin lifecycle is lazy.nvim's, LSP is Neovim's native
`vim.lsp.config`/`vim.lsp.enable` stack, and the config's own code is the
options, keys, and the handful of seams between plugins that no plugin owns.
This document is the map of that code: what each piece is for and the load
order it relies on. Day-to-day rules are in `../AGENTS.md` and the
extension points in `extending.md`; what the editor does and which key does
it are `features.md` and `keys.md`; the reasoning behind each decision is in
the phase design documents under `design/`.

## Boot

`init.lua` is one line: `require('ucw').boot()`. `lua/ucw/init.lua` then runs,
in this order:

1. Disable the python/ruby/perl/node provider hosts.
2. Eager config that needs no plugin: `ucw.options`, `ucw.builtin-plugins`
   (`vim.g` flags for bundled filetype plugins), `ucw.keys`, `ucw.extras`.
3. `ucw.lsp.attach.setup()` — one `LspAttach` autocmd, eager on purpose:
   clients arrive from `vim.lsp.enable()` (the lspconfig spec, loaded by
   filetype) and from rustaceanvim (which starts its own client without
   nvim-lspconfig ever loading), and only an autocmd installed before either
   covers both.
4. `bootstrap_lazy()`: clone lazy.nvim if absent, checked out at the commit
   `lazy-lock.json` pins for it. lazy.nvim records itself in the lockfile but
   cannot install itself, so cloning a moving branch (`stable`) made every
   fresh install write back a different commit than the one checked in, which
   the CI "lockfile did not drift" gate then failed on. Updating lazy.nvim is
   `:Lazy update`, same as any plugin.
5. `require('lazy').setup` with two imports, in order: `ucw.plugins`, then
   `ucw.plugins.user`. lazy.nvim merges specs that share a plugin across
   imports, later import winning, so a same-named file under `plugins/user/`
   overrides or extends the base spec (nothing lives there today).
6. `ucw.gui.setup()` when running under a GUI frontend (Neovide).

Everything past step 5 is lazy.nvim's: eager specs load before `VimEnter`,
the rest on their `event`/`ft`/`cmd`/`keys` triggers.

## Layout

```
init.lua
lua/ucw/init.lua              boot() above
lua/ucw/options.lua           vim.opt.*, commented with *why*
lua/ucw/keys.lua              core editor remaps that belong to no plugin
lua/ucw/keys/actions.lua      named actions those keys call
lua/ucw/extras.lua            small autocmd features (yank highlight, autoread, :W)
lua/ucw/targets.lua           context predicates for spec `cond`
lua/ucw/toggles.lua           editor-level Snacks.toggle objects (<leader>u)
lua/ucw/utils.lua             helpers (bufdelete, jumplist rule, is_gui, FileWatcher)
lua/ucw/git.lua               neogit <-> codediff seam, commit-message float
lua/ucw/health.lua            :checkhealth ucw
lua/ucw/gui.lua               Neovide options
lua/ucw/lsp/                  see "LSP"
lua/ucw/neotree/              neo-tree helpers used by its spec
lua/ucw/textobjects/          ipython cell textobject/motions
lua/ucw/plugins/*.lua         one lazy.nvim spec per plugin
lua/ucw/plugins/user/         same-named overrides (empty)
after/lsp/<server>.lua        per-server LSP settings, table-only
ftplugin/<ft>.lua             filetype options + conform formatters_by_ft
scripts/                      keymap-snapshot, keys-doc, luarc-lint-config, tui-drive
tests/                        mini.test suite (see testing.md)
```

## Targets

`lua/ucw/targets.lua` is what is left of the old "target" idea: four
predicates — `is_gui`, `is_firenvim`, `is_vscode`, `is_full_ui` —
used as `cond = ...` on specs. `is_full_ui` (not firenvim, not vscode-neovim)
gates the tabline, the gutter, sessions, folding, indent guides and the whole
LSP stack (lspconfig, mason, lazydev, lsp_progress, rustaceanvim, clangd
extensions); which-key is gated narrower, on `not is_vscode` (it stays under
firenvim); the statusline, file tree and picker load everywhere. A spec with
`cond` false is
absent from lazy.nvim's plugin table entirely — its `keys =` are not
registered, `:Lazy` does not list it — so code that reaches into such a
plugin from an embedded context must not assume it exists.

The same predicate gates two autocmd-driven behaviours outside any spec:
format-on-save (under firenvim a `BufWrite` is the push back to the web page,
not a save) and treesitter's boot-time parser install (which also requires a
UI to be attached and the `tree-sitter` CLI on `PATH`; absent the CLI it
notifies once and skips).

## Plugin specs

One file per plugin under `lua/ucw/plugins/`, returning a lazy.nvim spec. The
file is the plugin's whole configuration: its `opts`/`config`, its
`dependencies`, its `cond`, and **its keys**. Phase 8 moved every plugin's
keymaps into its own spec's `keys =`; `which-key.lua` keeps only the
`<leader>` group headers, the core editor keys, and the few leaves that
belong to the editor rather than a plugin. Toggles are `Snacks.toggle`
objects (editor-level ones in `toggles.lua`, plugin-owned ones in the
plugin's `config`), so which-key renders their live state.

Conventions the suite enforces, each with the reason it exists:

- **`keys =` makes a spec lazy.** An eager plugin with keys needs an explicit
  `lazy = false` (`tests/test_keys.lua` "eager specs" census).
- **Every `<leader>` first-level entry is a group header registered at boot**,
  lowercase label, explicit icon, `mode = { 'n', 'x' }` (first-level census).
- **A `desc` never looks like a rhs** (`^<cmd>`, `^:`), in any registration
  mechanism — the symptom of an entry that lost its rhs.
- **Prefix placement** follows the table in `design/phase9-keybindings.md` §5,
  not the plugin's README defaults.

The **`<leader>` map** as built (Phase 9, trial-adjusted in 9.5):
`c` code · `f` find (files) · `s` search (everything else) · `g` git
(`go` octo) · `u` toggles · `r` REPL · `q` quit/session · `b` buffer ·
`w` window · `t` tab · `n` notifications · `l` `:Lazy` · `?` buffer-local
popup. `d` (debugger) and `a` (AI) are reserved. Non-leader: native `gr*` for
LSP, `[`/`]` + letter for previous/next (`d` diagnostic, `q` quickfix, `c`
hunk, `h` python cell, `r` reference), `q` closes read-only windows,
`\`/`|` open the file tree, `<C-p>` frecency picker, `Tab`/`S-Tab` cycle
buffers with `<C-i>` kept for the jumplist.

## LSP

Neovim's native four-layer config does the composition:
`vim.lsp.config('*')` → nvim-lspconfig's bundled `lsp/<name>.lua` (kept
installed only as that data source; never `require`d) → this repo's
`after/lsp/<name>.lua` → any explicit `vim.lsp.config(name, ...)`.

- **`lua/ucw/lsp/servers.lua`** is the one registration point: a server is
  one line (`name = { filetypes }`), which drives `vim.lsp.enable()`
  (`lsp/init.lua`), mason-lspconfig's `ensure_installed`, and the `ft =`
  trigger that loads the LSP specs at all. Binaries that must be installed
  but not enabled here (formatters, servers another plugin owns) go through
  `mason-tool-installer.lua`.
- **`lua/ucw/lsp/attach.lua`** is everything per client, per buffer:
  buffer-local keys (`ucw.lsp.actions` paths, so a renamed API is a test
  failure rather than a silent dead key), inlay hints mirrored from the
  global flag, codelens, `snacks.words` reference navigation, and the
  per-server capability edits (ruff's `hoverProvider` off, because it
  answers hover with nothing and `vim.lsp.buf.hover` reports every empty
  answer).
- **`lua/ucw/lsp/vscode.lua`** is the only writer of `client.settings`. It
  rebuilds them from an attach-time snapshot on every `.vscode/` change
  (one watcher per directory, not per client); `ltex_dict.lua` writes the
  dictionary sidecar files and calls `vscode.reload()`.
- **Mason appends** its `bin/` to `PATH` rather than prepending, so a
  project's own toolchain (`mise`, venv, `nix develop`) wins; `:checkhealth
  ucw` prints where each declared binary actually resolved.

`after/lsp/<server>.lua` files are **table-only**: a function field there
replaces nvim-lspconfig's rather than composing with it.

## Formatting, folding, completion, pickers

- **conform** formats; `formatters_by_ft` is set per filetype in
  `ftplugin/<ft>.lua` next to that filetype's options (conform is eager, so
  the table exists before any ftplugin runs). Servers that self-report
  formatting but should not format (`lua_ls`, `texlab`) carry
  `lsp_format = 'never'`. Format-on-save is gated on `is_full_ui`.
- **ufo** folds on treesitter queries, `vim-fold-cycle` for the fold keys;
  **mini** supplies `ai` textobjects (`g[`/`g]` are mini.ai's edge motions,
  not directions), `surround`, `move`, `icons`; **autopairs** is its own spec.
- **blink.cmp** completes with the pure-Lua fuzzy matcher (the Rust matcher
  has an open upstream SIGSEGV) and owns signature help on `<C-k>`.
- **snacks** owns `vim.ui.input`, `vim.ui.select`, every picker key, and the
  notification renderer that **noice** (which wraps `vim.notify`) draws
  through. Its picker config silently drops unknown keys; check the field
  name before assuming a setting did nothing.
- **treesitter** is on the rewritten `main` API (no `configs.setup`);
  parsers auto-install at boot under the gate above. After a Neovim upgrade,
  update nvim-treesitter and `:TSUpdate` together — a query/runtime mismatch
  kills the async parse coroutine and every redraw errors until `:e!`.

## Git

**neogit** for status/log/commit, **codediff** for every diff view (diffview
is out: its hand-rolled async re-enters libuv through nested `vim.wait()` and
segfaults), **gitsigns** for the gutter and hunk keys. `lua/ucw/git.lua` is
the seam neither plugin has: `<CR>` on a commit in any neogit buffer opens it
in codediff (bound buffer-locally on `BufWinEnter`, because neogit's own
mappings land after `FileType`), and `<leader>gm` shows the commit message
from either a neogit buffer or a codediff tab. neogit's `diff_viewer` is set
to `codediff` explicitly; its autodetect prefers diffview when both are
installed.

## Sessions and notifications

**auto-session** saves per directory (suppressed under `/tmp` and the like);
before saving it closes auxiliary windows, including codediff tabs, whose
panes are real file buffers and would otherwise survive restore as stray
splits. **noice** routes messages; LSP progress renders only in lualine.
`<leader>n` is the history, `<leader>un` dismisses.

## Binary dependencies

`mise.toml` pins the binaries the repo needs to work on itself (stylua,
lua-language-server, ruff, taplo); `just deps` installs them plus a test-only
copy of mini.nvim into `deps/` at the lockfile's commit. Neovim finds the
same binaries through `PATH`, so a session started outside the project falls
back to Mason's copies. See `design/phase6.5-binary-deps.md`.

## Where the reasoning lives

The 2026 modernization (2026-07-25 to 2026-09-14) is complete: engine,
LSP, keys, tests and CI are all in the form this document describes, and
the phase series is closed. Each phase has a design document (proposal →
decision → as-built) and an independent acceptance review under `design/`:

| phase | subject | design | review |
|---|---|---|---|
| 1–2 | engine → lazy.nvim, spec conversion | (in-tree comments) | — |
| 3 | LSP on native layers; settings composition | `phase3-lsp-redesign.md`, `phase3-settings-composition.md` | `phase3-acceptance-review.md` |
| 4 | folding, comments, diagnostics | `phase4-folding-comments.md` | `phase4-acceptance-review.md` |
| 5 | sessions, notifications, picker | `phase5-session-notify-picker.md` | `phase5-acceptance-review.md` |
| 6 | formatting and linting | `phase6-format-lint.md` | `phase6-acceptance-review.md` |
| 6.5 | binary dependencies | `phase6.5-binary-deps.md` | `phase6.5-acceptance-review.md` |
| 7 | CI | `phase7-ci.md` | `phase7-acceptance-review.md` |
| 8 | keymap registration | `phase8-keymap-registration.md` | `phase8-acceptance-review.md`, `-2.md` |
| 9 | keybindings | `phase9-keybindings.md` | `phase9-acceptance-review.md` |
| 9.5 | trial-period tuning | `phase9.5-trial-period.md` | (covered by the Phase 9 review) |

A design document is the record of its own phase; where a later phase
superseded a decision, the earlier document says so inline and points
forward. This file and `AGENTS.md` are the current description.

What comes next is not a phase. The two features Phase 9 reserved prefixes
for — a debugger under `<leader>d` and AI integration under `<leader>a` —
and anything else that gets added, land as ordinary changes: the spec, its
keys, its tests and the update to this file and `AGENTS.md` in the same
change. A design document under `design/` is warranted only when a change
reopens a recorded decision; the placement rule for its keys is
`design/phase9-keybindings.md` §5.
