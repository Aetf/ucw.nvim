# Phase 3 design: LSP subsystem redesign

Status: **revision 2** — reviewed against the original 14 goals, corrected by a
second round of measurements. Nothing implemented yet.

Goal 5 of the modernization ("redesign the LSP system"), plus the LSP half of
goal 1 ("keep the systemd per-context loading idea"). This document records what
the current subsystem actually does (measured, not assumed), what Neovim 0.12's
native LSP framework actually guarantees (also measured), and proposes a design
that follows from those two.

Revision 2 changed four load-bearing claims that revision 1 got wrong, and added
the activation model, which revision 1 omitted entirely. Each is called out
inline as **[r2]**.

---

## 1. What is actually running today

The current design routes everything through `lua/ucw/lsp/hooks.lua`, which
offers three registration points: `on_server_setup`, `on_new_config`,
`on_attach`. Two of them are installed by monkey-patching nvim-lspconfig
internals (`lspconfig.util.on_setup` and
`lspconfig.util.default_config.on_new_config`); the third uses an `LspAttach`
autocmd.

Servers, however, are started by mason-lspconfig's `automatic_enable = true`,
which calls **native `vim.lsp.enable()`**. That path never touches lspconfig's
setup functions.

Measured on a real Rust buffer with two clients attached:

| hook | times fired |
|---|---|
| `on_server_setup` | **0** |
| `on_new_config` | **0** |
| `on_attach` | 8 (4 handlers × 2 clients) |

### Consequences, all verified

* **Every file in `lua/ucw/lsp/lang/` is dead.** All nine modules expose only
  `on_server_setup` and/or `on_new_config`. `ucw.lsp.lang.rust_analyzer` is even
  `require`d at attach time (the dispatcher looks it up by server name) but has
  no `on_attach` key, so it loads and does nothing. ~300 lines, zero effect.
* **`.vscode/settings.json` support is half-dead.** The initial load
  (`on_new_config_workdir`) never runs; the live-reload file watcher
  (`watch_settings_change`, on attach) still does. So settings are only ever
  applied if the file changes *after* the server is already up.
* **cmp-nvim-lsp's capability merge had silently stopped working** — same root
  cause. Already fixed in Phase 2 by moving to `vim.lsp.config('*', ...)`.
* **`ufo.lua` still registers `on_server_setup`** for its `foldingRange`
  capability, so folding has been advertised to nobody for as long as
  mason-lspconfig has been starting servers natively.
* Two of the dead modules (`taplo.lua`, `zeta_note.lua`) are empty stubs: a
  comment and `local M = {} return M`.

### Separately broken / stale

* **Two rust-analyzer clients attach to every Rust buffer**: `rust_analyzer`
  (mason-lspconfig `automatic_enable`) and `rust-analyzer` (rustaceanvim).
  Both advertise `inlayHintProvider`, so inlay hints render twice —
  `let v: String: String = ...`. Measured live:
  `vim.lsp.get_clients({bufnr=0})` → `{ "rust_analyzer", "rust-analyzer" }`.
* **[r2] rustaceanvim's own attach hook has never matched its own client.**
  `rustaceanvim.lua` calls `register_on_attach('rust_analyzer', ...)`, the
  dispatcher filters with `string.find(client.name, ptn)`, and rustaceanvim
  names its client **`rust-analyzer`** (`rustaceanvim/lsp/init.lua:11`).
  `string.find('rust-analyzer', 'rust_analyzer')` is `nil`. So the `<leader>a`
  grouped-code-action keymap exists today *only* because the duplicate
  mason-started `rust_analyzer` client matches — the exact client this phase
  deletes. Verified live: `<leader>a` is buffer-locally mapped in a Rust
  buffer. **Removing the duplicate without fixing the filter silently removes
  `<leader>a`.** This must be a regression test, not a code comment.
* `enable_inlay_hint` is unconditional: no `supports_method` guard, no toggle.
* `vim.lsp.codelens.refresh({ bufnr = bufnr })` is deprecated in 0.12.
* **[r2] `setup_keymap` is NOT a duplicate of the global leader bindings.**
  Revision 1 claimed it "duplicates, verbatim, the global leader bindings
  already declared in `which-key.lua`" and proposed deleting it. That is wrong.
  The block registers **buffer-local, bare-`g` bindings** — `g0` `gW` `ge` `gD`
  `gd` `gt` `gH` `gr`, plus `<M-CR>` `<M-S-CR>` `<c-k>` `<M-S-r>` — whose *right*
  sides match the global `<leader>l*` bindings but whose *left* sides do not
  exist anywhere else. Measured live in an attached Rust buffer:

  ```
  maparg('gd', 'n') → { buffer = 1, rhs = '<cmd>Telescope lsp_definitions<cr>',
                        desc = 'Go to definition' }
  ```

  It also still works despite using which-key v2's `wk.register`, because v3
  keeps a functioning compatibility shim (`which-key/init.lua:36` →
  `M.add(mappings, { version = 1 })`). So these bindings are live and must be
  **ported, not deleted** (see §5).
* `sumneko_lua.lua` is named after a server that no longer exists under that
  name (it is `lua_ls` now), so even a working dispatcher would never find it.
* `lua/ucw/lsp/utils.lua`'s `lazy_root_pattern` exists to work around
  lspconfig's root resolution; native `root_markers` covers the same ground.

---

## 2. What the native framework actually guarantees

Measured against the installed Neovim 0.12.3, not inferred from docs.

### Config layering

Four layers merge into the final per-server config:

```
vim.lsp.config('*', {...})        lowest
  <rtp>/lsp/<name>.lua            ← nvim-lspconfig ships 407 of these
    <rtp>/after/lsp/<name>.lua
      vim.lsp.config('<name>', {...})   highest
```

* **Table fields deep-merge across layers**, including across repeated calls to
  the same layer: `vim.lsp.config('*', {capabilities = A})` followed by
  `vim.lsp.config('*', {capabilities = B})` yields A ∪ B (measured — this is
  what lets blink.cmp and nvim-ufo both contribute capabilities without
  knowing about each other).
* **[r2] List-like tables are replaced wholesale, not merged by index.**
  Measured: `root_markers = {'a','b'}` then `root_markers = {'x'}` resolves to
  `{'x'}`. This is the intuitive behaviour, but it is *not* what plain
  `vim.tbl_deep_extend` does, so it is worth stating: an `after/lsp/<name>.lua`
  that sets `root_markers` must list **every** marker it wants, including the
  ones upstream provided.
* **Function fields do NOT compose — the highest layer that defines one wins
  outright.** Measured: a `before_init` at `'*'` reaches every server that does
  not define its own; a server that defines its own silently discards ours.
  This is the single most important constraint on the design.
* **Among rtp `lsp/<name>.lua` files, the *later* rtp entry wins.** In this
  config `~/.config/nvim` is rtp index 1 and `nvim-lspconfig` is index 6, so a
  plain `lsp/<name>.lua` **at the repo root would lose to nvim-lspconfig's**,
  not override it. This rules out the layout the original plan sketched.
* **`after/lsp/<name>.lua` is the layer that works** — with one correction.

#### [r2] Where `~/.config/nvim/after` actually lands in the rtp

Revision 1 said it ends up "dead last, ahead of every plugin". Half right, and
the wrong half matters. Reading lazy.nvim's `lua/lazy/core/loader.lua:467`
(`add_to_rtp`): a plugin's own directory is inserted right after
`~/.config/nvim`, and the plugin's `after/` directory is inserted right after
**the first rtp entry ending in `/after`**. Once `~/.config/nvim/after` exists
it *is* that first entry (nvim appends it at the end of the base rtp, and
`~/.local/share/nvim/site/after` does not exist on this machine — measured: the
only `/after` entries in the live rtp today are two plugin ones, at 53 and 54 of
54). So:

* our `after/lsp/` **beats every plugin's `lsp/`** — including nvim-lspconfig's,
  which is the whole point; but
* our `after/lsp/` **loses to any plugin's `after/lsp/`**, because those get
  inserted after it.

That is not hypothetical: **`mason-lspconfig.nvim` ships an `after/lsp/`
directory**. It currently contains exactly one file, `omnisharp_mono.lua`, which
we do not use — so there is no live conflict, but the invariant is fragile
enough to deserve a test (§6) and a documented escape hatch: an explicit
`vim.lsp.config('<name>', {...})` call is the true top layer and always wins.

### Function fields that already exist upstream

Of nvim-lspconfig's 407 configs, 7 define `before_init`, 10 `on_init`, 25
`on_attach`. Measured for exactly the servers this config will run:

| server | upstream function fields |
|---|---|
| `lua_ls` | `on_init` |
| `pyright` | `on_attach` |
| `texlab` | `on_attach` |
| `clangd` | `on_attach`, `on_init` |
| `ruff` `ltex_plus` `marksman` `taplo` `jsonls` | none |
| (`rust_analyzer`, not used) | `before_init`, `on_attach` |

So **no server we enable defines `before_init`**, and any design that puts a
fan-out in `on_attach` or `on_init` at the `'*'` layer would be silently
clobbered for `lua_ls`, `pyright`, `texlab` and `clangd`.

### `before_init` timing, and what it cannot do

Confirmed with a live rust-analyzer: inside `before_init(params, config)`,
`config.root_dir` is already resolved (`/tmp/rust_test_proj`) and
`params.rootUri` is set, so root-dependent `settings` customization has a
working native home — that is literally the upstream docstring's example.

**[r2] But `before_init` runs *after the server process has been spawned*.**
`client.lua:30-32`: *"Invoked before LSP `initialize` phase (**after `cmd` is
invoked**)"*; `cmd_env` is consumed at `client.lua:488`. So `before_init` is a
valid replacement for `on_new_config` when the target is `settings`, and **not**
when the target is `cmd`/`cmd_env`/`cmd_cwd`. This matters for exactly one
thing, texlab's `CHKTEXRC` injection — see §5.

### [r2] `commands` is a table field

`vim.lsp.ClientConfig.commands` (`client.lua:72`) is a
`table<string, fun(command, ctx)>` map that overrides `vim.lsp.commands`
per client. It is a **table**, so it deep-merges like any other data. ltex's
three `_ltex.*` handlers therefore need no `on_init` hook at all — they are a
plain table in `after/lsp/ltex_plus.lua`. This removes the last reason revision 1
had for an `on_init` mechanism.

### `LspAttach`

Plain autocmds. Multiple handlers compose naturally, they fire for **every**
client regardless of how it was started (including rustaceanvim's, which
bypasses lspconfig entirely), and they already work today. This is the one part
of the existing design that was right, and revision 2 leans on it harder.

### [r2] Exit is not blocked by LSP

`vim.lsp.ClientConfig.exit_timeout` defaults to **`false`**, so the built-in
`VimLeavePre` handler (`lsp.lua:1178`) computes `max_timeout = 0` and calls
`vim.wait(0, ...)` — it never waits for a server to shut down. Measured `:qa!`
→ process gone:

| scenario | quit latency |
|---|---|
| no LSP | 33 ms |
| rust-analyzer just started | 47 ms |
| rust-analyzer after 5 s of indexing | 60 ms |

14–27 ms of overhead. "Quitting waits for the language server" was a real
problem on older Neovim; upstream fixed it. No workaround needed, and none
should be added.

---

## 3. Activation model

Revision 1 did not cover this at all, which left goal 1 unaddressed for the one
subsystem where it matters most. Today LSP is a manual, all-or-nothing switch:
`<leader>ll` fires `User UcwLspEnable`, and six specs
(`nvim-lspconfig`, `mason.nvim`, `mason-lspconfig.nvim`, `rustaceanvim`,
`clangd_extensions.nvim`, `lsp-progress.nvim`) are gated on that event.

### Requirement

LSP should come up **by itself** when it is actually useful, without measurably
slowing down opening a file, and without slowing down quitting.

### Measurements

Quitting: not a problem (§2, above).

Opening: dispatching `User UcwLspEnable` synchronously takes **36 ms** wall
clock — but almost none of that is on the path that actually produces LSP:

| plugin | load time | needed to get a client attached? |
|---|---|---|
| `nvim-lspconfig` | **0.2 ms** | yes — it is just the config registry |
| `mason.nvim` | 1.3 ms | yes — only to prepend its `bin/` to `PATH` |
| `rustaceanvim` | 0.1 ms | yes, on Rust only |
| `clangd_extensions.nvim` | 0.5 ms | yes, on C/C++ only |
| `mason-lspconfig.nvim` | **22.7 ms** | **no** — it only runs `ensure_installed` |
| `lsp-progress.nvim` | **11.8 ms** | **no** — it is a statusline component |
| `require('ucw.lsp').config()` | 0.7 ms | yes |

So the real hot path is small, and the two expensive plugins are both
housekeeping that has nothing to do with getting diagnostics on screen.

**[r3] Re-measured on the finished implementation**, because the table above was
taken with everything loading together off one `User` event and does not carry
over unchanged:

| | measured |
|---|---|
| startup, no code file | **66-77 ms** (was 84 ms before this phase - mason.nvim is no longer eager) |
| `ft` trigger: load nvim-lspconfig + mason + `ucw.lsp.setup()` | **~3 ms** |
| …including resolving configs and starting the client for the triggering buffer | **~6 ms** |
| first file opened in a session, *plain .txt, no LSP at all* | **~27 ms** |
| mason-lspconfig at VeryLazy | 8-23 ms, depending on registry cache warmth |
| lsp-progress at LspAttach | 3-12 ms |
| `:qa!` with a client attached | 52-63 ms, indistinguishable from no LSP |

The design claim survives with room to spare: the LSP trigger costs about a
ninth of what opening the first buffer already costs for reasons that have
nothing to do with LSP.

### Decision: `ft`-triggered, split hot/cold

* **Hot path** — `nvim-lspconfig` and `mason.nvim` get
  `ft = require('ucw.lsp').filetypes()`. lazy.nvim's `ft` handler loads the
  plugins, runs their `config` (which is where `vim.lsp.enable()` happens), and
  *then* replays the event — `handler/event.lua:132 M.trigger` → `:161
  nvim_exec_autocmds`, and for `FileType` specifically it deliberately does not
  exclude pre-existing augroups (`:107`), so the autocmd `vim.lsp.enable()` just
  registered does fire for the buffer that triggered the load. This is why no
  manual `doautocmd FileType` (today's `<leader>ll` trick) is needed.
  `rustaceanvim` gets
  `ft = { 'rust' }`; `clangd_extensions.nvim` gets the C-family list. Opening a
  Lua/Rust/Python/… file therefore costs ~1.6 ms extra, once per session.
* **Cold path** — `mason-lspconfig.nvim` moves to `event = 'VeryLazy'`, off
  both the startup and the file-open path. Its only remaining job is
  `ensure_installed`; it does not need to run before a server starts, only
  before the *next* one is missing — which is also why it cannot ride
  `LspAttach`, since a server that is not installed never attaches.
  **[r3]** `lsp-progress.nvim` went to `event = 'LspAttach'` instead of
  VeryLazy: it is a statusline component with nothing to show until a client
  exists, so this costs nothing at all on a session that never opens code.
* **[r3] The attach handlers are installed eagerly from `ucw.boot`, not from
  the `ft` trigger.** This was implemented the other way first and it was
  wrong: clients arrive from two directions, and `nvim-lspconfig` never loads
  for a Rust buffer at all (rust is not in `servers.lua` — rustaceanvim owns
  it). Hanging `ucw.lsp.attach.setup()` off nvim-lspconfig's `config` therefore
  left Rust buffers with no keymaps, no inlay hints and no `.vscode` settings.
  Nothing errored; it was found by driving a real TUI, and every test in the
  suite passed while it was broken because they all force-loaded nvim-lspconfig
  first. The handlers are client-agnostic behaviour and cost one autocmd, so
  they belong with the config core.
* **Context gating** — every LSP spec also gets `cond = require('ucw.targets').is_full_ui`,
  so the `vscode` and `firenvim` contexts never load any of it. This is the
  concrete goal-1 payoff: "which units run in which context" survives as a
  one-line predicate instead of a target graph.
* `<leader>ll` is retired as an activation switch. Startup does not change at
  all: nothing LSP-related is eager.

### Alternatives evaluated and rejected

* **Command-triggered loading** ("start the server the first time you ask for
  references / a code action"). Rejected: the features people actually notice
  first are the passive ones — diagnostics, inlay hints, completion — so a
  command trigger would mean opening a file and seeing nothing until you
  explicitly poke it. It optimizes the wrong 1.6 ms.
* **Per-language strategies** (light servers eager, heavy ones deferred).
  Rejected: it buys nothing measurable — the cost of a "heavy" server is the
  language server's own indexing, which is in a separate process and does not
  block Neovim — and it costs a second activation mechanism to understand and
  maintain, against goals 3 and 10. If rust-analyzer's indexing ever becomes an
  interactive problem, the right lever is rust-analyzer's own settings, not
  Neovim's load order.
* **Eager at startup.** Rejected: makes `mason-lspconfig` and friends part of
  the startup budget for no benefit, and makes the capability-ordering
  invariant below fragile.

### The one ordering invariant this creates

Everything that contributes to `vim.lsp.config('*', { capabilities = ... })`
must have run before the first `vim.lsp.enable()`. Today both contributors
(`blink.cmp`, `nvim-ufo`) are eager specs, so this holds by construction and
gets *stronger* under `ft`-triggered LSP (startup strictly precedes the first
`FileType`). It is still an invariant that a future lazy-loaded plugin could
break silently, so §6 asserts it with a test rather than a comment.

---

## 4. Proposed design

`ucw.lsp.hooks` existed because Neovim had no usable extension points; it does
now, so the guiding rule is **use the native layers, add nothing on top**.
`hooks.lua` — three bespoke registration functions, pattern matching, two monkey
patches — is deleted with nothing replacing it. A plugin that needs attach-time
behaviour writes its own `LspAttach` autocmd: one line, no knowledge of any
private API of this config.

Everything maps onto a native mechanism:

| concern | native mechanism |
|---|---|
| which servers exist, and what loads LSP | `lua/ucw/lsp/servers.lua` (one table) |
| per-server settings | `after/lsp/<name>.lua` (layer 3) |
| custom server commands (`_ltex.*`) | `commands` table in that same file |
| per-client, per-buffer behaviour (keymaps, inlay hints, codelens, `.vscode` settings) | `LspAttach` autocmd |
| cross-cutting table data (capabilities) | `vim.lsp.config('*', ...)` — tables only, never functions |

### Layout

```
after/lsp/            -- per-server config; nvim discovers these natively.
  lua_ls.lua          -- ONLY for servers that need customization.
  texlab.lua
  ltex_plus.lua
  marksman.lua
  pyright.lua
  clangd.lua
lua/ucw/lsp/
  servers.lua         -- the single registration point: server -> filetypes
  init.lua            -- enable(), server_names(), filetypes()
  attach.lua          -- LspAttach handlers, each guarded by supports_method
  vscode.lua          -- .vscode/settings.json, rewritten onto LspAttach
  ltex_dict.lua       -- ltex dictionary helpers
```

**[r2] `servers.lua` replaces revision 1's "every server gets a file, even if it
is `return {}`".** Revision 1 wanted the `after/lsp/` directory listing to be
the registration point, which forced empty files for servers with no settings,
and — more importantly — could not work at all once activation is `ft`-driven:
lazy.nvim needs the filetype list *before* nvim-lspconfig is on the rtp, so it
cannot be derived from the registry at that moment. One small table solves both:

```lua
-- lua/ucw/lsp/servers.lua
-- The servers this config runs, and the filetypes that should bring LSP up.
-- Static on purpose: lazy.nvim needs the ft list before nvim-lspconfig is on
-- the runtimepath. tests/test_lsp.lua asserts it matches what nvim-lspconfig
-- actually declares, so it cannot drift silently.
return {
  lua_ls    = { 'lua' },
  pyright   = { 'python' },
  ruff      = { 'python' },
  texlab    = { 'tex', 'plaintex', 'bib' },
  ltex_plus = { 'tex', 'bib', 'markdown', 'gitcommit' },
  marksman  = { 'markdown', 'markdown.mdx' },
  taplo     = { 'toml' },
  jsonls    = { 'json', 'jsonc' },
  clangd    = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
  -- rust is deliberately absent: rustaceanvim owns rust-analyzer (§5)
}
```

That one table drives three things: `vim.lsp.enable(server_names())`,
mason-lspconfig's `ensure_installed`, and the `ft =` trigger on the LSP specs.
`after/lsp/<name>.lua` stays purely optional customization — a server with
nothing to say gets no file, instead of a file saying nothing.

nvim-lspconfig stays installed purely as the `cmd`/`filetypes`/`root_markers`
registry for its 407 servers, never `require`d.

### mason-lspconfig

**Kept, `automatic_enable = false`, moved to `event = 'VeryLazy'`.** The flag is
what starts a second rust-analyzer, so it goes; the plugin earns its keep by
turning the same server list into installation, using its Mason-package
name mapping (verified live: `lua_ls → lua-language-server`,
`ltex_plus → ltex-ls-plus`, `jsonls → json-lsp`, and all the rest resolve):

```lua
require('mason-lspconfig').setup {
  automatic_enable = false,
  ensure_installed = require('ucw.lsp').server_names(),
}
```

Verified: `ensure_installed` is still supported in mason-lspconfig v2
(`features/ensure_installed.lua`) and is skipped under `is_headless`
(`init.lua:31`), so it will not slow the test suite down.

### Attach handlers

```lua
-- lua/ucw/lsp/attach.lua  (sketch)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    keymaps(client, args.buf)                       -- ported verbatim, see §5
    if client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
    end
    if client:supports_method('textDocument/codeLens') then
      -- refresh on BufEnter/InsertLeave, using the non-deprecated call shape
    end
    require('ucw.lsp.vscode').attach(client)        -- see §5
  end,
})
```

### rustaceanvim: why it cannot be "just another server"

Worth stating plainly, because it is the one asymmetry left in the design.

rustaceanvim manages its own rust-analyzer client on purpose, and its README is
explicit: *"Do not call the `nvim-lspconfig.rust_analyzer` setup or set up the
LSP client for `rust-analyzer` manually, as doing so may cause conflicts."*
There is **no option to make it defer to an externally started client** — the
plugin is built around owning the lifecycle, because that is what lets it do
standalone (non-Cargo) files, reload-workspace, grouped code actions, runnables
and testables, expand-macro, view HIR/MIR, and the DAP wiring.

So it is genuinely either/or:

* **Keep rustaceanvim** (proposed): it owns rust-analyzer, `rust_analyzer` is
  absent from `servers.lua`, and mason-lspconfig no longer auto-enables one.
  That *is* the fix for the duplicate client — the current double attach is
  precisely the conflict the README warns about, caused by `automatic_enable`.
* **Drop rustaceanvim**, add `rust_analyzer` to `servers.lua`, and Rust becomes
  uniform with everything else — at the cost of every feature listed above.

The asymmetry is smaller than it looks: because all attach behaviour now rides
on `LspAttach`, rustaceanvim's client picks up the same keymaps, inlay hints and
codelens as every other server with no special-casing. The only thing that
differs is *who calls `vim.lsp.start`*. `rust_analyzer.lua`'s single setting
(`checkOnSave.command = 'clippy'`) folds into
`vim.g.rustaceanvim.server.default_settings`.

**[r2] Its own `LspAttach` handler must filter on `rust-analyzer`, not
`rust_analyzer`** — see §1. A test asserts `<leader>a` exists on a Rust buffer.

---

## 5. Decisions (settled)

### Server set

Nine servers. Rust is deliberately absent — rustaceanvim owns it.

| server | `after/lsp/` file | content |
|---|---|---|
| `lua_ls` | yes | LuaJIT runtime, `vim` global, telemetry off; workspace library delegated to lazydev |
| `pyright` | yes | `didChangeWatchedFiles.dynamicRegistration = true` — measured **not** covered by the global capabilities (`false`), so it is a real setting |
| `ruff` | no | replaces pylsp. The registry has both `ruff` and the deprecated `ruff_lsp`; we use `ruff` |
| `texlab` | yes | backward search, build/chktex/synctex settings (see the CHKTEXRC note below) |
| `ltex_plus` | yes | dictionary machinery + the three `_ltex.*` entries in `commands` |
| `marksman` | yes | `root_markers` extended for Obsidian (below) |
| `taplo` | no | old module was already an empty stub |
| `jsonls` | no | its only setting (`snippetSupport`) measures `true` already via blink's global capabilities — pure deletion |
| `clangd` | yes | keeps `clangd_extensions.nvim`; note upstream defines both `on_attach` and `on_init`, so **only table fields** may go in our file |

Dropped: `pylsp` (superseded by ruff), `sumneko_lua` (renamed to `lua_ls`),
`rust_analyzer` (rustaceanvim's), `zeta_note` (retired upstream).

**Python ends up as pyright + ruff** — pyright for types, ruff for lint. That is
the current mainstream split and lines up with Phase 6, where ruff also becomes
the formatter.

#### `lua_ls` + lazydev.nvim — adopt

The old module set `workspace.library = nvim_get_runtime_file('', true)`, which
hands lua_ls the *entire* Neovim runtime plus every plugin, up front, on every
Lua buffer. `lazydev.nvim` (folke, successor to neodev.nvim) instead watches for
`require('...')` and `---@module` in the open file and adds only those paths to
the workspace on demand — same completions, far less indexing. Spec is literally
`{ 'folke/lazydev.nvim', ft = 'lua' }` and it needs no lua_ls settings of its
own, so `after/lsp/lua_ls.lua` keeps only the runtime/globals/telemetry bits.

#### Markdown: `zeta_note` → `marksman`, tuned for Obsidian

zeta-note is archived upstream ("retired"); marksman is its author's successor
project and the direct replacement. The primary use is an **Obsidian vault**,
with occasional standalone `.md` files, so root detection needs one addition —
upstream ships `root_markers = { '.marksman.toml', '.git' }`, and a vault
usually has neither:

```lua
-- after/lsp/marksman.lua
return {
  -- an Obsidian vault is a workspace: wiki-links and backlinks are only
  -- meaningful across the whole vault, and a vault has a .obsidian/ dir but
  -- usually no .git. Inner table = same priority tier.
  root_markers = { { '.marksman.toml', '.obsidian' }, '.git' },
}
```

Note the list-replacement semantics from §2: this must repeat `.git`, it is not
appended to upstream's list. A standalone `.md` file matches no marker and
falls back to marksman's single-file mode, which still gives heading/link
completion and diagnostics within the file — which is exactly the "occasional
standalone file should still be ergonomic" requirement.

(Deeper Obsidian integration — daily notes, templates, vault-aware pickers — is
an `obsidian.nvim`-shaped question, out of scope for an LSP phase. Noted for a
later phase rather than smuggled in here.)

#### `ltex` → `ltex_plus`

`ltex-ls` upstream is abandoned; `ltex-ls-plus` is the maintained fork and
nvim-lspconfig ships `lsp/ltex_plus.lua`. The dictionary code is the main
consumer and is being rewritten anyway, so it targets the fork directly. The
three `_ltex.*` handlers become a `commands` table (§2), not an `on_init` hook.

#### texlab: verify the workarounds before porting them

Two of the three texlab customizations are root-dependent workarounds for
upstream bugs, and **[r2] one of them cannot be expressed in `before_init` at
all** because `cmd_env` is consumed at spawn time:

* `cmd_env.CHKTEXRC = root_dir` (texlab#309, 2021) — **issue is closed
  upstream**.
* `settings.texlab.rootDirectory = root_dir` (texlab#571, 2022) — **also
  closed**.

Per goal 2, the default is **delete both** and only reinstate what a real
editing session proves is still needed. If `CHKTEXRC` turns out to still be
required, the native home is a function-valued `cmd` (which receives the
resolved `config`, so it can pass `env` to `vim.lsp.rpc.start`) — recorded here
so the option is known, not because it should be written speculatively.

The third, `settings.texlab.forwardSearch` + the `texlab_backward_search` global,
is real functionality and moves to `lua/ucw/lsp/texlab_sync.lua` unchanged
(minus the `nvim_win_set_curosr` typo already fixed in Phase 0).

### `.vscode/settings.json`: unify onto `LspAttach`

**[r2] Changed from revision 1**, which put a `before_init` in each
`after/lsp/<name>.lua`. Three mechanisms were on the table:

| option | cost |
|---|---|
| `before_init` per server file | one line copied into every file; adding a 10th server silently loses the feature |
| `before_init` at `'*'` | one line total, works today (no enabled server defines `before_init`), but needs a guard test forever |
| **`LspAttach` + `workspace/didChangeConfiguration`** | one extra round trip after the server starts |

Chosen: **`LspAttach`**. It collapses initial load and live reload into a single
code path — the live-reload watcher already does exactly this and is the only
part of the current implementation that ever worked — it needs no registration
in any per-server file, and it covers clients started outside `vim.lsp.enable()`
(rustaceanvim's) for free. The cost is that a server starts with default
settings and is corrected microseconds later, which is the same contract the
watcher already relies on.

Implementation notes: snapshot `client.settings` on first attach so reloads
merge over the static base rather than compounding; dedupe by `client.id`;
`client:notify('workspace/didChangeConfiguration', { settings = ... })` replaces
the deprecated `client.workspace_did_change_configuration`.

Rust: rustaceanvim has its own `load_vscode_settings = true`. The unified
handler makes that redundant, so the plan is to turn it **off** and let one
mechanism serve every client. Verification must include a real Rust project with
a `.vscode/settings.json`; if rust-analyzer's settings shape turns out to need
rustaceanvim's own handling, the fallback is to re-enable its flag and skip
`rust-analyzer` in our handler. Stated as a decision with a named fallback
rather than left as a surprise.

### Keymaps: port verbatim, redesign in Phase 9

**[r2] Changed from revision 1**, which proposed deleting `setup_keymap` as a
duplicate — it is not (§1). The block is translated mechanically from which-key
v2's `wk.register` to v3's `wk.add { ..., buffer = args.buf }` inside
`attach.lua`, **with no content changes**: same `g0/gW/ge/gD/gd/gt/gH/gr`,
`<M-CR>`, `<M-S-CR>`, `<c-k>`, `<M-S-r>`. Whether these should be replaced by
Neovim 0.11's native `grn`/`gra`/`grr`/`gri`/`grt`/`gO` is a *binding content*
question, and Phase 9 owns it; mixing it in here would entangle mechanism review
with taste review, which the phase split exists to prevent.

Same reasoning for inlay hints: this phase adds the `supports_method` guard and
a named toggle action in `keys/actions.lua`, but **does not bind a key to it** —
Phase 9 places it.

The genuinely redundant piece — nothing here duplicates `which-key.lua` — turns
out to be zero lines. Revision 1's "delete the duplicated block" item is dropped.

### mason-lspconfig: keep, `automatic_enable = false`, `VeryLazy`

See §3 and §4.

---

## 6. Migration and verification

Order, each step independently testable:

1. Add `lua/ucw/lsp/servers.lua` + `attach.lua`, rewrite `init.lua`; keep
   `hooks.lua` in place temporarily so nothing regresses mid-change. Port
   `setup_keymap` to `wk.add` here.
2. Add `after/lsp/` with the six customization files; set
   `automatic_enable = false` and wire `ensure_installed`. **This is the step
   that fixes the duplicate rust client** — and the step that must land together
   with rustaceanvim's `rust-analyzer` attach-filter fix, or `<leader>a`
   disappears.
3. Re-gate the specs: `ft` on the hot path, `VeryLazy` on mason-lspconfig and
   lsp-progress, `cond = is_full_ui` on all of them; retire `<leader>ll` as an
   activation switch.
4. Delete `hooks.lua`, `lang/`, and `utils.lua`'s `lazy_root_pattern`.
5. Rewrite `vscode.lua` onto the unified `LspAttach` path.
6. Install the newly declared servers via Mason and actually edit a file in each
   language (see the second risk in §7).

Verification, in the spirit of the previous phases (measured, not assumed):

* **Regression-test the two bugs this phase is about**: a Rust buffer attaches
  exactly **one** client and renders inlay hints once; `<leader>a` is still
  mapped on that buffer (the `rust-analyzer` filter fix).
* **Assert the merge, not the bookkeeping.** Revision 1 proposed asserting that
  the `after/lsp/` listing equals the enable list equals `ensure_installed` —
  tautological once all three derive from `servers.lua`. Assert instead that
  `vim.lsp.config['lua_ls']` carries **both** upstream's `cmd`/`filetypes`/
  `root_markers` **and** our `settings`, and that
  `vim.lsp.config['marksman'].root_markers` contains `.obsidian` *and* `.git`.
* **Assert `servers.lua` has not drifted**: after loading nvim-lspconfig, every
  server's declared `filetypes` must equal the list in `servers.lua`.
* **Assert no plugin shadows us**: no loaded plugin ships an
  `after/lsp/<name>.lua` for any name in `servers.lua` (§2's fragile rtp
  invariant).
* **Assert the capability-ordering invariant**: at first
  `vim.lsp.enable()`, `vim.lsp.config['*'].capabilities` contains both blink's
  completion capabilities and ufo's `foldingRange`.
* An integration test that an `LspAttach` handler fires for a client started
  outside `vim.lsp.enable()` (guards the rustaceanvim unification claim).
* Live TUI check: open a Lua file cold, confirm a client attaches with no
  manual step; confirm startup time is unchanged; confirm `:qa!` latency is
  unchanged from the numbers in §2.
* `:checkhealth vim.lsp` — "Enabled Configurations" should match `servers.lua`
  exactly, with no surprise auto-enables.

## 7. Risks

* **`ft`-triggered activation makes the capability-ordering invariant
  load-bearing.** Covered by a test, but a future lazy-loaded plugin that
  contributes `'*'` capabilities will fail it rather than silently degrade —
  which is the point.
* **The server set is a behaviour change, not a port**, because the current
  per-server settings have not been in effect. Whatever we enable will behave
  differently from today — probably better, but differently. Worth a real
  editing session per language before calling the phase done. `clangd` and
  `marksman` are brand new here and have never run in this config.
* **First boot on a machine without the binaries** will log "not executable"
  for servers Mason has not installed yet, because `ensure_installed` now runs
  at `VeryLazy` rather than before enable. Acceptable and self-healing; noted so
  it is not mistaken for a regression.
* **`vim.lsp.config` function-field semantics are load-bearing.** If a future
  nvim-lspconfig release adds `on_attach`/`before_init` to a server we
  customize, an explicit `vim.lsp.config(name, ...)` call would still win — but
  the upstream function would then be silently dropped. This design avoids the
  problem by putting **only table fields** in `after/lsp/` and all behaviour in
  `LspAttach`; the `clangd` and `lua_ls` files in particular must stay
  table-only.
* **Our `after/lsp/` loses to a plugin's `after/lsp/`** (§2). No live conflict
  today; a test guards it, and `vim.lsp.config(name, ...)` is the escape hatch.
* **Dropping `<leader>ll` removes an escape hatch** for "LSP is misbehaving,
  turn it off". `:lsp` (native, 0.12) and `:Lazy` cover the diagnosis side;
  if a manual off-switch is still wanted, `vim.lsp.enable(names, false)` is the
  one-liner — flagged for Phase 9 to place, not designed here.
