# Extending

The extension points of `ucw.nvim`: which file to touch for each kind of
change, what the config-owned modules export, and the tooling around it.
`AGENTS.md` is the short rulebook (the traps); this is the reference behind
it. Everything named here has a test or gate that fails when it is broken;
the *guard* column names it.

## Recipes

| to add… | touch | guard |
|---|---|---|
| a plugin | `lua/ucw/plugins/<name>.lua` returning a lazy.nvim spec; `:Lazy install` and commit `lazy-lock.json` | `just ci` (boot), `just lint` (library list from the lockfile), CI's lockfile-drift step |
| keys for a plugin | its spec's `keys = { { lhs, rhs, desc = …, silent = true, mode = … } }`; prefix per `design/phase9-keybindings.md` §5; then `just keys-doc` | `test_keys.lua` (desc scan, eager census), `test_keys_doc.lua` |
| a new `<leader>` namespace | a free letter (§3 of the same document), the group header in `lua/ucw/plugins/which-key.lua` (lowercase label, explicit `icon`, `mode = { 'n', 'x' }`), a row in `test_keys.lua`'s group census | the census |
| a toggle | `Snacks.toggle.new { id, name, get, set }:map('<leader>u<x>')` in `lua/ucw/toggles.lua` (editor-level) or the owning spec's `config()`; add the id to `test_keys.lua`'s toggle census | that census; a behaviour case where the state can be read back |
| a language server | one line in `lua/ucw/lsp/servers.lua`; `after/lsp/<name>.lua` only if it needs settings (table-only) | `test_lsp.lua` config-layering set, `:checkhealth ucw` |
| a formatter | `ftplugin/<ft>.lua`: `require('conform').formatters_by_ft.<ft> = { 'tool' }`; the binary in `lua/ucw/plugins/mason-tool-installer.lua` unless a server provides it; `lsp_format = 'never'` if a server also claims formatting and must not | `test_format.lua` |
| a filetype's options | `ftplugin/<ft>.lua` | — |
| a treesitter parser | `ensure_installed` in `lua/ucw/plugins/treesitter.lua` | `test_treesitter.lua` |
| a textobject | `custom_textobjects` in `lua/ucw/plugins/mini.lua` (treesitter captures via `gen_spec.treesitter`, or a function like `ucw.textobjects.ipython.cell`) | `test_ipython_cell.lua` for the function kind |
| a per-buffer LSP behaviour | `lua/ucw/lsp/attach.lua` (general) or the plugin's own `LspAttach` autocmd (server-specific) | `test_lsp.lua` attach set |
| an LSP-backed action | `lua/ucw/lsp/actions.lua`'s table; bind it by name | `test_lsp_actions.lua` |
| a per-machine override | `lua/ucw/plugins/user/<name>.lua` with the same plugin name (merged over the base spec, later import wins) | — |
| a binary the repo itself needs | `mise.toml` | `just deps` |

## Module reference

Only what other files may call. Everything else in a module is local.

### `ucw.targets` — context predicates for `cond`

`is_gui()` (Neovide), `is_firenvim()`, `is_vscode()`, `is_full_ui()`
(neither embedded context). A spec with `cond` false is absent from
lazy.nvim's plugin table: its keys are not registered and `require`ing it
throws, so code reaching into it from elsewhere must `pcall` or share the
gate.

### `ucw.lsp.servers` — the server list

A table `name = { filetypes }`. It is the single source for
`vim.lsp.enable()`, mason-lspconfig's `ensure_installed` and the `ft`
trigger that loads the LSP stack; `ucw.lsp.server_names()` and
`ucw.lsp.filetypes()` are the derived, sorted views. A server whose client
another plugin owns (rust-analyzer) is *not* listed; its binary goes in
`mason-tool-installer.lua`.

### `ucw.lsp.actions` — named LSP entry points

`actions[name] = { desc, mode?, args?, lsp = 'buf.rename' | picker =
'lsp_references' | fn = { mod = 'conform', fn = 'format' } }` — exactly one
of `lsp` (a dotted path under `vim.lsp`), `picker` (a `Snacks.picker`
source) or `fn` (`require(mod)[fn]`). Entry points are resolved at press
time by name, so a renamed upstream function fails with the action's name
instead of leaving an inert key; `test_lsp_actions.lua` resolves every
path. `rhs(name)` returns the closure to bind; `call(name)` runs it.

### `ucw.lsp.attach` — per client, per buffer

`setup()` seeds the global inlay-hint flag, calls `ucw.lsp.vscode.setup()`
(which installs the `LspDetach` half) and installs the `LspAttach` autocmd
(called from `ucw.boot`, before any plugin, so clients rustaceanvim starts
without nvim-lspconfig are covered). The buffer-local key table (action names)
and the per-server capability edits (`ruff = { 'hoverProvider' }`) are
locals at the top of the file; there is no other API.

### `ucw.lsp.vscode` — workspace settings

The only writer of `client.settings`. `setup()` installs the `LspDetach`
handler (called from `ucw.lsp.attach.setup()`). `attach(client)` snapshots the
client's settings, loads `<root>/.vscode/settings.json` plus the user-scope
directory (`global_dir()`), composes them over the snapshot and watches
both directories; `reload(client)` recomposes; `detach(client_id)` stops the
watch when the last buffer leaves. `SIDECAR_KEYS` lists the settings keys
that may also be `<dir>/<key>.<variant>.txt` files, unioned into
`settings[key][variant]`; `sidecar_path(dir, key, variant)` names one.
Anything file-backed belongs here, never in a second writer — the ltex
module writes the sidecar files and calls `reload()`.

### `ucw.lsp.ltex_dict` — ltex's three off-spec commands

Implements `_ltex.addToDictionary`, `_ltex.hideFalsePositives` and
`_ltex.disableRules` as client commands writing the project's sidecar
files; nothing else in the config is ltex-specific.

### `ucw.toggles`

`setup()` registers the editor-level `Snacks.toggle`s (`inlay_hints`,
`diag_virtual_lines`, `diagnostics`, `wrap`, `spell`) and their
`<leader>u` keys; called from which-key's `config()`. A toggle is global
unless its state is inherently per buffer; the inlay-hint one drives the
global flag and `attach.lua` mirrors it into new buffers. Read the registry
with `rawget(require('snacks.toggle').toggles, id)` — `Snacks.toggle.get()`
manufactures a toggle for an unknown id.

### `ucw.keys.actions`

Named callbacks for the core keys: `bufdelete`, `bufnext`/`bufprev`
(bufferline with a plain fallback), `jump_file(dir)` (the file-granular
jumplist step), `cell_jump(dir)`, `iron_send_block(opts)`, `hoverK`,
`clear` (`<Esc>`).

### `ucw.utils`

`bufdelete(bufnr, force)` — close a buffer and land the window on the
jumplist's previous *file* (then the alternate buffer, then the next
normal buffer) instead of the buffer list's neighbour;
`win_jump_other_buf(win, buf, dir, count)` — the landing rule behind it and
behind `jump_file`; `is_gui()`; `t(str)` — termcodes; `FileWatcher.new(ms)`
with `:start(path, cb)` / `:stop()` / `:close()` — a debounced
`uv.fs_event`, used by `ucw.lsp.vscode`.

### `ucw.git`

The neogit ↔ codediff seam: `commit_under_cursor()` (an oid or stash ref
from any neogit buffer, nil on a file row), `open_diff(ref)` (a codediff tab
for `ref^..ref`), `show_message()` (the commit message float, resolving the
commit from neogit or the current codediff tab).

### `ucw.textobjects.ipython`

`cell(ai_type, id, opts)` — a mini.ai textobject spec for `# %%` cells
(`h` trims blank edge lines, `H` keeps them; `a` includes the marker).

### `ucw.health`

`check()` behind `:checkhealth ucw`. Reads its declared set from
`ucw.lsp.servers` and the mason-tool-installer spec; adds no third list.

### `ucw.neotree.helpers`

The fold-key emulation and navigation commands neo-tree's spec binds
(`neotree_z*`, `move_in`/`move_out`, `first_sibling`/`last_sibling`,
`system_open`, `toggle_hidden`), plus `width_fit_content`.

## Testing

mini.test, driven by `just unit` / `just int` / `just all` / `just ci`;
every command goes through `mise exec --` so the pinned formatters and
linters are the ones under test. `docs/testing.md` has the mechanics; the
helper API in `tests/aux/lua/helpers.lua`:

- `H.new_unit_test(opts)` — a child with only the repo and mini.test on
  `rtp`; for pure modules (`ucw.lsp.actions`, `ucw.textobjects.ipython`,
  `.luarc.json` checks).
- `H.new_integration_test(opts)` — a child that boots the whole config
  (fresh `XDG_DATA_HOME` per run; plugins are installed into it on first
  use). `opts.hooks` are chained with the boot hooks.
- `H.boot_embedded(child, 'vscode' | 'started_by_firenvim')` — reboot an
  integration child as an embedded context; the marker has to exist before
  `ucw.boot()` because `cond` is evaluated while `init.lua` sources.

The child's traps (feedkeys, hit-enter, noice routing, waiting on state
rather than time) are in `docs/testing.md`; the rules for what a test must
prove are in `../AGENTS.md`.

## Tooling

- `just deps` — pinned binaries (`mise.toml`) and a test-only `mini.nvim`
  into `deps/` at the lockfile's commit.
- `just lint` — `lua-language-server --check` over the repo with the
  installed plugins' `lua/` as library (`scripts/luarc-lint-config.lua`
  builds `.luarc.lint.json` from `.luarc.json` and `lazy-lock.json`;
  `.luarc.json` itself is what the editor uses and is checked in).
- `just fmt` / `just fmt-check` — stylua.
- `just keys-doc` — regenerate the tables in `docs/keys.md`
  (`scripts/keys-doc.lua`) from a real boot.
- `just tui …` — `scripts/tui-drive.sh`: a real Neovim in a detached tmux
  session with a `--listen` socket. Verbs: `start [nvim args]`, `send
  <keys>` (Neovim notation), `keys <tmux keys>`, `cmd <ex>`, `expr`, `lua`,
  `capture`, `capture-color`, `messages`, `screenshot`, `stop`. Start and
  stop it from `/tmp` (an auto-session suppressed directory), or stopping
  overwrites this repo's saved session; asynchronous views need a state
  poll before a capture. `docs/tui-observation.md`.
- `scripts/keymap-snapshot.lua` — dump every global mapping with its
  option flags for diffing two boots (`vim.g.ucw_snapshot_path`, then
  `:luafile`); the proof of "no key changed" behind any relocation.
- CI (`.github/workflows/ci.yml`): `just ci` on stable and nightly
  (nightly advisory), the lockfile-drift check, `just lint`, `just fmt-check`.
  Reproduce any job locally with the same recipe; `VAR=x just …` does not
  reach a recipe (`docs/testing.md`). The lockfile-drift check locally:

  ```sh
  MISE_DATA_DIR=$HOME/.local/share/mise XDG_DATA_HOME=/tmp/scratch XDG_CONFIG_HOME=~/.config NVIM_APPNAME=nvim \
    mise exec -- nvim --headless '+Lazy! install' +qa && git diff --exit-code lazy-lock.json
  ```

  `MISE_DATA_DIR` must be pinned alongside `XDG_DATA_HOME`, or mise's own
  store moves with it and mise reinstalls everything first.
