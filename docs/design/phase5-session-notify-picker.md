# Phase 5 design: sessions, notifications, and the picker

> Revision history
>
> * **r1** (2026-08-02) — proposal. Everything under "What is actually running
>   today" is measured on this machine, not read off a README. Decisions D1–D3
>   were put to the user before this document was written and their answers are
>   recorded in §2; D4–D8 are open and are what this revision is for.
> * **r2** (2026-08-02) — D4–D7 answered (§2), D8 narrowed to a look-and-pick
>   after rendering all three notifier styles under this config's own theme.
>   No change to the proposal itself; D4 and D5 grew explicit "this is a
>   behaviour change / verify by pressing the key" notes.
> * **r3** (2026-08-04) — as built. D8 answered (`compact`). §5a records the
>   verification results, including **two claims from r1 that verification
>   falsified** (W1, W2): `close_unsupported_windows` does *not* run on the
>   manual-save path, so the hook could not delegate to it; and
>   `restore_shortmess` turned out not to be a dead workaround but an active
>   bug. §5's projections are replaced with measured numbers, and §3.2 gained a
>   third layer of staleness nobody had looked for.
> * **r4** (2026-08-04) — after the acceptance review
>   (`docs/design/phase5-acceptance-review.md`, findings R1–R8). Eight findings,
>   two of them live regressions; all fixed. The pattern, and it is the third
>   phase running: **the new test guards what was changed on purpose, and the
>   findings land on what changed as a side effect.** §3.1's `previewer = false`
>   row and §3.2's window-sweep rule are annotated below with what they actually
>   do; §5a's verification results stand as written and are not rewritten — the
>   review file is the record of what they missed.
> * **r5** (2026-08-05) — second-round check on R2's own fix, same pattern
>   again. R2's exemption tested `buftype == '' and name ~= ''`; a completely
>   unnamed (`[No Name]`) scratch buffer with typed, unsaved text has no name,
>   so it kept failing that test and was still being swept on every manual
>   save — a regression the pre-Phase-5 filetype-list rule never had (it only
>   matched specific filetypes, never touching plain `buftype == ''`).
>   `sessionoptions` has `blank`, so the window is session-worthy; fixed by
>   dropping the name condition entirely, `if buftype == '' then return false`.
>   Also corrected an overclaim in R2's own writeup: "mksession records such a
>   buffer perfectly well ... so the window was carrying real, restorable
>   state" was only measured same-process, where restore's `bufexists()`
>   branch reuses the still-open modified buffer. On a real quit and restart —
>   the case auto-session exists for — `mksession` never serializes unsaved
>   text for any buffer; only the window and its file association come back.
>   Measured directly: save, `:qa!`, fresh headless process, `:AutoSession
>   restore` — the window returns, the typed text does not. Not a regression
>   from R2 (the text was never going to survive a real restart, fix or no
>   fix), but the claim as written overstates what the fix protects. See
>   `lua/ucw/plugins/auto-session.lua`'s `unsupported_window` comment, which
>   now says both things precisely. 113 cases, green twice; new test reverse-
>   verified (revert the one-line fix, exactly `an unnamed buffer with unsaved
>   text keeps its window` goes red).

Plan file row: *Phase 5 — Tech-island consolidation: session / notify (git and
picker: no change)*.

**The title of that row is wrong in two directions and this document says so up
front.** The picker *does* change, and the biggest single win in this phase is
neither session nor notify: it is a plugin the plan file never mentions.

---

## 0. What the plan file got wrong

The Phase 5 row was written from research, before anyone looked at the running
config. Four of its claims do not survive contact:

1. **"Session mgmt → consolidate onto `mini.sessions`."** The stated benefit was
   "a lighter dependency footprint … not less bespoke code". But the dependency
   it wanted to shed — `session-lens` — has been **deprecated since 2024-07**
   and its functionality has already been absorbed *into auto-session itself*.
   The lighter footprint is available without leaving auto-session, and leaving
   auto-session would mean giving up three built-in options it has grown since
   this config was written that may replace the bespoke hooks outright. The
   plan's own row concedes mini.sessions "does not reduce custom code". Going
   the other way does.
2. **"Fuzzy picker: reopened … flag to the user."** Correctly flagged, and it
   *was* flagged (§2, D1). But the framing — "keep Telescope, still fine" — is
   built on the premise that Telescope is the incumbent and everything else is a
   new dependency. Measured, that premise is false: **`snacks.picker` is already
   loaded at every startup and is already the `vim.ui.select` handler**. This
   config has had two fuzzy pickers for a while; the question was never whether
   to add one, it was which of the two to delete.
3. **"Notifications … drop `nvim-notify`, keep snacks + noice."** This one is
   right, and §1.4 confirms the mechanism it predicted. Nothing to correct.
4. **What the row does not mention at all:** `remote-nvim.nvim` — the single
   most expensive plugin at startup on this machine (10.3 ms), which has never
   successfully connected to anything, and which is the *only* reason
   Telescope is loaded eagerly. And `structlog.nvim` — a logger, dead upstream
   since January 2023, with **zero callers**.

---

## 1. What is actually running today

All numbers below come from a real TUI boot (`scripts/tui-drive.sh`), reading
`require('lazy').stats()` and `lazy.core.config.plugins[...]._.loaded`.

Baseline: **50 plugins, 38 loaded at startup, 93.8 ms**. *(One sample, taken in
`$HOME` — which is not a git repository, so gitsigns and neogit never come up.
§5 re-measures properly, in a project directory and three boots per side.)*

### 1.1 There are already two fuzzy pickers

```
picker.enabled=true  ui_select=true  snacks.picker loaded=true  telescope loaded=true
```

`lua/ucw/plugins/snacks.lua` sets `picker = { ui_select = true }`, so every
`vim.ui.select` in the config and in every plugin already goes through
`snacks.picker`. Telescope owns 13 explicit keybindings plus 7 entries in
`ucw.lsp.actions`. The file comment on `snacks.lua` still says "Mostly used for
its `vim.ui.input` impl", which stopped being true when `ui_select` was added.

Every source the Telescope call sites need already exists in snacks, verified by
reading `snacks.picker.config.sources` out of the running instance:

```
lsp_definitions=true lsp_type_definitions=true lsp_implementations=true
lsp_references=true lsp_symbols=true lsp_workspace_symbols=true
diagnostics=true diagnostics_buffer=true files=true grep=true lines=true
buffers=true command_history=true recent=true help=true resume=true
```

`rg` and `fd` are both on `PATH` (`executable()` → 1), which is what
`snacks.picker`'s `files`/`grep` finders shell out to.

The one Telescope picker with no snacks equivalent is `Telescope reloader`
(`<leader>Tr`). The user has approved deleting it (§2, D1).

### 1.2 `remote-nvim.nvim`: never used, and it is why Telescope is eager

Top 12 plugins by load time, measured:

```
remote-nvim.nvim=10.3  lazy.nvim=9.8  telescope.nvim=8.9  nvim-base16=7.7
neo-tree.nvim=7.3  nvim-treesitter=6.5  blink.cmp=6.3  mason-lspconfig.nvim=3.7
lualine.nvim=3.1  rainbow-delimiters.nvim=3.1  snacks.nvim=3.0  mini.nvim=2.7
```

And the load *reasons*:

```
remote-nvim.nvim      = { start = "start" }              -- eager, no lazy trigger
telescope.nvim        = { plugin = "remote-nvim.nvim" }  -- pulled in by it
telescope-fzf-native  = { plugin = "telescope.nvim" }
session-lens          = { plugin = "auto-session" }
```

`lua/ucw/plugins/remote-nvim.lua` has a `cond` but **no `cmd`/`event`/`ft`**, so
it is a start plugin, and its `dependencies` list forces Telescope up with it.
Telescope's own spec says `cmd = 'Telescope'`; that lazy trigger has never
fired first. So the #1 and #3 most expensive plugins at startup are a
never-used remote-editing plugin and the picker it drags along.

Evidence it has never been used:

* `~/.local/share/nvim/remote-nvim.nvim/workspace.json` is **0 bytes**; the
  directory was created 2024-06-10 and nothing has been written since.
* Its `client_callback` on Linux runs `konsole -e nvim --server …`, falling back
  to `neovide`. **Neither `konsole` nor `neovide` is installed on this machine.**
  Even a successful connection could not open a client.
* Its picker is hardcoded (`require('telescope').extensions['remote-nvim'].connect()`
  in `command.lua:10`) with no configuration option and no fallback.

### 1.3 Sessions: old option names, a deprecated dependency, and a redundant hook

`:checkhealth auto-session`, captured from a real TUI:

```
Config
- ✅ OK No config issues detected

Current Config
- You have old config names. You can update your config to:
  {
    auto_restore = false,
    bypass_save_filetypes = { "neotree", "help" },
    log_level = "warn",
    post_restore_cmds = { <function 1>, <function 2> },
    pre_save_cmds = { <function 3>, <function 1> },
    suppressed_dirs = { "~/", "/dev/shm", "/tmp" }
  }
…
- Selected picker: telescope
```

Three separate facts in that output:

* `auto_session_suppress_dirs` and `bypass_session_save_file_types` are **old
  names**, translated at runtime by `config.lua`'s `check_old_config_names()`
  compatibility table. They work, but the healthcheck nags and the compat table
  is not a contract.
* **`Selected picker: telescope`** — auto-session already auto-detects the
  picker. It supports `telescope | snacks | fzf | select`. It will pick up
  snacks by itself once Telescope is gone; no code change needed beyond deleting
  `session-lens`.
* `session-lens`' own README opens with
  `⚠️ DEPRECATED - Session Lens is now part of auto-session. ⚠️`. Last commit
  2024-07-16. It costs 0.9 ms at every startup to provide a command
  (`:Telescope session-lens search_session`) that `:SessionSearch` already is.

**And the part the plan file could not have known:** `close_unsupported_windows`
defaults to `true`, and this config does not turn it off — so
`auto-session/lib.lua:300` has been closing every window whose buffer is not a
readable file, on every save, *in addition to* the bespoke `close_aux_windows`
in `pre_save_cmds`. The two overlap heavily. What they do **not** share:

> **[r3, corrected]** "on every save" is wrong, and it is the one conclusion in
> this section that was read out of a config table instead of traced to a call
> site. It runs on the **autosave** path only. See §5a, W1 — the comparison
> below is still accurate, but it does not license removing our sweep.

| | `close_aux_windows` (ours) | `close_unsupported_windows` (theirs) |
|---|---|---|
| floating windows | closes by `win_config.relative` | closes only if buffer is not a readable file |
| `fern`/`Trouble`/`*tree*`/`Neogit` | closes by filetype | closes (their buffers are not files) |
| `buftype == 'help'` | closes | **does not** — a help file *is* readable |
| diffview | `view:close()` + `dispose_view()`, i.e. proper teardown | closes the window, leaves diffview's view registry dangling |
| terminals | closes if float | explicitly preserved (`buf_type ~= 'terminal'`) |

So the ours-only residue is: help windows, floats over real files, and
diffview teardown. Everything else is duplicated work. Separately,
`close_filetypes_on_save` (`{ "checkhealth" }` by default) is the declarative
version of the filetype half.

`restore_shortmess` (`post_restore_cmds`) is a workaround with a comment that
says "sometimes session messes with shortmess". `lua/ucw/options.lua:124`
already does `vim.opt.sessionoptions:remove('options')`, which is exactly the
setting that would let a session file restore `shortmess`. **This is a prime
suspect for a workaround that has been dead for years** — to be A/B'd, not
assumed (D6).

### 1.4 Notifications: the `vim.notify` chain, measured

Read out of the running instance:

```
vim.notify == require('notify')                 -> false
vim.notify == require('noice.source.notify').notify -> true
noice's saved _orig == require('notify')        -> true
Snacks.config.notifier                          -> {}   (i.e. not enabled)
```

So today: **`vim.notify` is noice**, noice routes to its `notify` *view*, whose
`backend` is declared `{ "snacks", "notify" }` (`noice/config/views.lua:67`),
and `SnacksView:is_available()` requires `_G.Snacks and Snacks.config.notifier.enabled`
(`noice/view/backend/snacks.lua:26`) — which is false — so it falls through to
the `notify` backend, i.e. nvim-notify.

Consequences:

* `nvim-notify.lua`'s `vim.notify = notify` assignment is **overwritten by
  noice** at startup and never takes effect. nvim-notify survives purely as
  noice's rendering backend.
* Enabling `Snacks.config.notifier` is *sufficient* to flip the backend — the
  documented default integration the plan file cited is real and is a two-line
  change. There is no adapter to write.
* Three call sites reach around `vim.notify` to nvim-notify directly and would
  break:
  * `lua/ucw/keys/actions.lua:144` — `require('notify').dismiss()` in `M.clear()`
    — **[r4]** and `M.clear` is what **`<Esc>` in normal mode** runs
    (`ucw/keys.lua:32`, a bare function reference that no grep for `clear()`
    finds). Listing it as a "call site" rather than as *what Escape does* is why
    §5a never presses it. Measured after the fact: the wider
    `noice.cmd('dismiss')` is safe there — it clears noice's live `_messages`
    set, not the `_history` the pickers read. Acceptance review, R3.
  * `lua/ucw/plugins/telescope.lua:55` — `pcall(telescope.load_extension, 'notify')`
  * `lua/ucw/plugins/structlog.lua:6,17` — see §1.5

### 1.5 `structlog`: a logger with no callers

* `Tastyep/structlog.nvim`, last upstream commit **2023-01-08**.
* Costs 2.3 ms at startup (`lazy = false, priority = 1000`).
* Configures three pipelines, one of which writes TRACE to `./test.log`
  (relative to cwd — it would litter whatever directory nvim was started in, if
  anything ever logged).
* `lua/ucw/log.lua` wraps it in an `M.logger()` accessor.
* **`grep -rn` across the whole config finds exactly one reference to
  `ucw.log`, and it is in `AGENTS.md`.** No Lua file calls it. Not one line has
  ever been logged through it.

The `pending_notify_calls` queue and the `User NotifyLoaded` autocmd in
`structlog.lua` + `nvim-notify.lua` exist solely to bridge structlog's
`NvimNotify` sink to a lazily-loaded nvim-notify. Both ends of that bridge are
being deleted.

---

## 2. Decisions

Decided by the user before this document (recorded verbatim in intent):

* **D1 — Picker: move to `snacks.picker`.** Rationale accepted from the user:
  snacks.picker has the fullest source coverage, and the plan file's fzf-lua
  argument ("matches the new LazyVim default") does not carry weight — LazyVim
  is one distribution, and it is a different project from lazy.nvim.
  `Telescope reloader` may be deleted rather than replaced.
* **D2 — Delete `remote-nvim.nvim`.** Never used, client callback broken on this
  machine, and it is what makes Telescope eager. With it gone, Telescope and
  `telescope-fzf-native` can be removed outright (no `make` build step left in
  the config).
* **D3 — Sessions stay on `auto-session`, modernised in place.** Do *not* migrate
  to `mini.sessions`. Delete `session-lens`, move to the new option names, and
  test case-by-case whether auto-session's built-in options can replace the
  bespoke hooks.

Raised in r1, answered by the user for r2:

* **D4 — `diagnostics` binds to snacks' `diagnostics_buffer`. This is a
  deliberate behaviour change, not a faithful port.** The entry is
  `desc = 'Diagnostics for current buffer'` but `cmd = 'Telescope diagnostics'`,
  and `:Telescope diagnostics` with no arguments lists **all** open buffers. So
  "port the behaviour" and "honour the description" disagree, and snacks forces
  the choice by splitting them: `diagnostics` (all) vs `diagnostics_buffer`
  (current). Resolved in favour of the description — the label that has been on
  screen in which-key all along is now true. **Recorded here explicitly because
  Phase 4's F2/F3 were exactly this shape** (scope quietly changed while moving
  code); the difference is that this one is on purpose and written down.
* **D5 — keep `ucw.utils.bufdelete`, wired as a custom snacks action on the same
  `<c-d>`, and verify the behaviour rather than assuming it.** The jumplist
  preference (previous *normal* buffer from the window's jumplist → the window's
  alternate buffer → next listed normal buffer → a fresh scratch buffer if none
  exists) is a deliberate choice this config made; snacks' own `bufdelete` action
  (bound to `dd`/`<C-x>`) does not have it. V1 presses the key and checks the
  window lands on the jumplist buffer, because a mis-wired custom action fails
  *silently* by falling back to snacks' default — visible only on screen.
  (Replacing `ucw.utils.buf_kill` with `Snacks.bufdelete` wholesale stays out of
  scope, §7.)
* **D6 — `restore_shortmess`: decide on the measurement (V6).** Delegated. It
  goes only if the A/B shows `&shortmess` is identical across save/restore
  without it; if the hook turns out to still be load-bearing it stays, with a
  comment saying what actually restores it.
* **D7 — notification keys as proposed.** `<leader>n` group "notifications":
  `nn` = `Snacks.picker.noice()` (the superset — noice registers this picker
  source itself when snacks.picker is present, `noice/config/init.lua:269`),
  `nh` = `Snacks.notifier.show_history()`, `nd` = dismiss.
* **D8 — `compact`.** All three styles were rendered
  under this config's real `base16-eighties` theme (scratch config +
  `tui-drive`, three parallel tmux sessions) rather than compared from the docs,
  because upstream only ships a screenshot of the default. Measured vertical
  cost per notification: **`fancy` 4 lines** (title row + timestamp + rule +
  body — the nvim-notify shape), **`compact` 3 lines** (icon and title inlaid
  into the top border), **`minimal` 1 line** (no border at all). Independently
  of which is chosen: `timeout = 3000` and `width = { min = 30, max = 55 }`,
  carried over from the nvim-notify config so the size does not change under us
  at the same time as the style.

---

## 3. Proposal

### 3.1 Picker: Telescope out, `snacks.picker` in

**Delete** `lua/ucw/plugins/telescope.lua`, `lua/ucw/plugins/remote-nvim.lua`.
**Do not** add a new plugin; `snacks.nvim` is already a start plugin.

`snacks.lua` grows a `picker` config section carrying over the four Telescope
`defaults` that were deliberate:

| Telescope setting | snacks equivalent |
|---|---|
| `sorting_strategy = 'ascending'` + `prompt_position = 'top'` | default layout already puts input on top, list ascending — assert, don't restate |
| `winblend = is_gui() and 10 or 0` | `win.input.wo.winblend` / `win.list.wo.winblend` / `win.preview.wo.winblend` |
| `mappings.i['<esc>'] = actions.close` | `win.input.keys['<esc>'] = { 'close', mode = { 'n', 'i' } }` |
| `pickers.buffers = { sort_lastused, sort_mru, previewer = false, <c-d> = safe_delete }` | `sources.buffers = { sort_lastused = true (already default), preview = false, win.input.keys['<c-d>'] = <custom action>, win.list.keys` } |

> **[r4, corrected]** Both halves of that last row shipped wrong, and both are
> in the acceptance review. **`preview = false` is not a switch** — the field is
> a previewer function or preset name and the resolver is `opts.preview or
> <default>`, so the buffers picker kept previewing; the switch is
> `layout = { preview = false }` (R1). And `win.list.keys`, which this very row
> names, was not carried over: snacks ships `<c-x>` and `dd` as *additional*
> delete bindings for this source, so two of the three delete keys bypassed the
> jumplist-aware delete that D5 is entirely about (R4).
| `extensions.fzf` (telescope-fzf-native) | n/a — snacks' matcher is built in; the `make` build step disappears |

Following the Phase 2 (`blink.cmp`) precedent: **do not restate snacks'
defaults**. Anything in the table above that turns out to already be the default
gets dropped from our config and recorded as such in §6, not copied across.

Call-site rewiring:

| Key | Was | Becomes |
|---|---|---|
| `<C-p>` | `Telescope find_files` | `Snacks.picker.files()` |
| `<M-S-f>` | `Telescope live_grep` | `Snacks.picker.grep()` |
| `<M-f>` | `Telescope current_buffer_fuzzy_find` | `Snacks.picker.lines()` |
| `<leader>Th` | `Telescope command_history` | `Snacks.picker.command_history()` |
| `<leader>Tr` | `Telescope reloader` | **deleted** (D1) |
| `<leader>bb` | `Telescope buffers` | `Snacks.picker.buffers()` |
| `<leader>ss` | `Telescope session-lens search_session` | `:SessionSearch` (§3.2) |
| `<leader>T` | group `telescope` | group renamed — `picker` |

And the seven `ucw.lsp.actions` entries, which is why that table exists at all
(its own comment says "keeping them named here means that decision touches one
file"): `lsp_definitions`, `lsp_type_definitions`, `lsp_implementations`,
`lsp_references`, `lsp_symbols` (note: **`lsp_document_symbols` → `lsp_symbols`**,
the name changes), `lsp_workspace_symbols`, and `diagnostics_buffer` (D4).

These are currently `cmd = 'Telescope lsp_definitions'` strings. snacks has no
ex-commands, so the `cmd` kind no longer fits. Rather than adding a third action
kind, **add a `picker` field** (`picker = 'lsp_definitions'`) resolved through
`Snacks.picker.<name>` in `M.rhs`/`M.call`, mirroring how the `lsp` field is a
dotted path resolved through `vim.lsp`. That keeps the Phase 3 property that
tests can assert every action resolves to something real without pressing keys —
`tests/test_lsp.lua:356` and `tests/test_lsp_actions.lua:76` currently assert the
literal string `'<cmd>Telescope lsp_definitions<cr>'` and will need updating in
kind, not just in value.

`octo.lua` gets `picker = 'snacks'` (validated enum in
`octo/config.lua:627`: `telescope | fzf-lua | snacks | default`).

`gitsigns.lua`'s block of `nvim_create_user_command` wrappers is commented
"so they can be used with telescope" — those are ex-commands consumed by
`command_history`/`:` completion, not by Telescope specifically. They stay;
the comment gets corrected.

### 3.2 Sessions: modernise `auto-session` in place

* Delete the `session-lens` dependency block. Do **not** set
  `session_lens.picker` — let auto-session auto-detect, and assert in
  verification that `:checkhealth auto-session` reports
  `Selected picker: snacks`.
* **`<leader>ss` → `:AutoSession search`, not `:SessionSearch`, and
  `legacy_cmds = false`.** [r3] r1 proposed `:SessionSearch` and that was wrong
  in the same way the option names were: `:Session*` are auto-session's
  *legacy* command names, kept alive by the `legacy_cmds` option, and pressing
  the key raised a `"SessionSearch" is deprecated. Use "AutoSession search"
  instead` toast. Found by pressing the key, not by reading — three of these
  (`<leader>sc`, `<leader>sr`, `<leader>ss`) were on legacy names, and turning
  `legacy_cmds` off is what stops the next one creeping back.
* Rename to current option names, exactly as the healthcheck prints them:
  `auto_restore_enabled` → `auto_restore`, `auto_session_suppress_dirs` →
  `suppressed_dirs`, `bypass_session_save_file_types` → `bypass_save_filetypes`.
  Verify the healthcheck's "You have old config names" block disappears.
* **Shrink the hooks against measurement, not against the README.** For each of
  the three, A/B what auto-session's built-ins already do (§4, V4–V6):
  * `close_aux_windows` → keep only the residue from §1.3's table. Expected
    outcome: the filetype list moves into `close_filetypes_on_save`, the
    generic float/drawer sweep is dropped as duplicated by
    `close_unsupported_windows`, and what remains is the help-window close plus
    the diffview `view:close()` + `dispose_view()` teardown — which no built-in
    can do, because it needs diffview's own API.
    **[r3] This is the part that verification falsified — see §5a, W1. The
    sweep had to stay.** What actually changed is its *rule*: the old
    hand-maintained filetype list (`fern`/`Trouble`/`*tree*`/`Neogit`) plus a
    blanket float close became upstream's own predicate — not a readable file
    and not a terminal — so there is no plugin-filetype list to keep current.
  * `consolidate_unnamed` → no built-in equivalent
    (`auto_delete_empty_sessions` deletes the *session*, `preserve_buffer_on_restore`
    filters the restore-time wipeout). Keep as-is, in both `pre_save_cmds` and
    `post_restore_cmds`.
  * `restore_shortmess` → D6.

### 3.3 Notifications: `nvim-notify` and `structlog` out

* **Delete** `lua/ucw/plugins/nvim-notify.lua`, `lua/ucw/plugins/structlog.lua`,
  `lua/ucw/log.lua`. With them go `pending_notify_calls`, `flush_pending_notify`,
  and the `User NotifyLoaded` autocmd — the whole lazy-notify bridge, which
  existed only to connect two things that are both being removed.
* `snacks.lua`: `notifier = { enabled = true, … }` (D8). This alone flips noice's
  backend, because `SnacksView:is_available()` tests exactly this flag.
* `noice.lua`: drop the `rcarriga/nvim-notify` dependency; **pin the backend
  explicitly** — `views = { notify = { backend = 'snacks' } }` — rather than
  relying on the `{ "snacks", "notify" }` ordering to resolve correctly, since
  the fallback entry now names a plugin that does not exist. Also drop the
  `notify = { enabled = true, view = 'notify' }` block: it restates noice's
  defaults, same class of cleanup as commit `df3f6c8` did for blink.
* `keys/actions.lua` `M.clear()`: `require('notify').dismiss()` →
  `require('noice').cmd('dismiss')`, which dismisses noice's own views *and*
  (through `SnacksView.dismiss`) `Snacks.notifier.hide()`. Keep the `pcall`.
* History bindings per D7.
* `AGENTS.md`'s "Two loggers" bullet (line 174) is wrong on both halves after
  this phase — `structlog` is gone and `nvimd` has not existed since Phase 1.
  Fix it here rather than leaving it for Phase 10; the nvimd rewrite of
  `architecture.md` stays Phase 10's.

---

## 4. Verification plan

Nothing in this list is satisfied by "tests are green". Phase 3 and Phase 4 both
shipped bugs past a green suite, and Phase 3's second round found that the
*fix commit* had fallen into the trap it was fixing. The rule from Phase 4
stands: **every new regression test gets reverse-verified** — revert the change
it guards and confirm that exactly that test goes red. And `just all` gets run
**twice**, because it has produced a false green before (`test_comment` racing
treesitter injection; `test_boot`'s "child stuck in mode r?").

* **V1 — every picker key actually opens a picker.** For all 13 rewired
  bindings, `tui-drive` `send` the key and `capture` the screen. Not `maparg`:
  Phase 3's P3 was a key that had a which-key label, no mapping, and nobody
  noticed for a month. New `tests/test_picker.lua` asserts every name used
  resolves to a real entry in `snacks.picker.config.sources` — the generic form,
  so a renamed upstream source fails loudly instead of at press time.
* **V2 — nothing references a deleted plugin.** Generic test, in the spirit of
  `tests/test_deprecations.lua`: grep the loaded config for `Telescope`,
  `require('telescope')`, `require('notify')`, `require('structlog')`,
  `remote-nvim`, `session-lens`, and assert `lazy.core.config.plugins` has no
  entry for any of them. This is the test that would have caught the
  `session-lens`-is-deprecated situation years earlier.
* **V3 — LSP pickers against a real server.** The seven LSP actions, exercised
  in a real TUI against real clients (lua_ls at minimum, and one more), checking
  that `lsp_symbols` shows document symbols and `lsp_references` jumps. The
  in-process fake server (`tests/test_lsp.lua`'s `cmd`-as-function trick) covers
  resolution but not rendering.
* **V4 — session save/restore round trip.** The highest-risk regression in the
  phase. `tui-drive`: open a project, split windows, open a neo-tree drawer, a
  help window, a terminal, and a diffview; `:SessionSave`; `:qa`; reopen;
  `:SessionRestore`. Assert window layout, no duplicate unnamed buffers, no
  leftover drawer, terminal preserved. Run it once **before** any change to
  capture the baseline, so "it was already like that" is a checkable claim.
* **V5 — hook-by-hook A/B.** For each piece of `close_aux_windows` proposed for
  deletion, disable it alone and confirm `close_unsupported_windows` really
  closes that window class. Specifically confirm the predicted asymmetries: help
  windows survive `close_unsupported_windows` (a help file is `filereadable`),
  terminals are preserved by it, and a diffview closed by it leaves
  `diffview.lib` state behind.
* **V6 — `restore_shortmess` (D6).** Capture `&shortmess` before save, after
  restore with the hook removed, and after restore with it present. Delete only
  if the three agree.
* **V7 — notification parity and history.** The style comparison itself is
  already done (D8, three styles rendered under the real theme in a scratch
  config). What is left is parity *in the real config*: a `tui-drive` screenshot
  of a toast under nvim-notify, captured **before** deleting it, against the
  same toast under the chosen `snacks.notifier` style — because the scratch
  render did not have noice in the chain, and noice formats the message before
  the backend ever sees it. Then the actual pain
  point: emit a `vim.notify`, an `:echo`, an error, and an LSP message; confirm
  each is retrievable from `Snacks.notifier.show_history()` and/or `:Noice`.
  Assert `vim.notify == require('noice.source.notify').notify` still holds and
  that the resolved backend is now `snacks`, i.e. re-run the §1.4 probe and get
  a different answer.
* **V8 — `:checkhealth`.** `auto-session` reports no old config names and
  `Selected picker: snacks`; `noice` does not warn about a missing notify
  backend (`noice/health.lua:118`).
* **V9 — startup and plugin count**, re-measured the same way as §1, reported in
  §6 as as-built.

---

## 5. Numbers (measured)

A/B'd properly rather than compared against the single r1 sample: the working
tree was stashed, the six plugins reinstalled with `:Lazy restore`, and three
boots taken in the same project directory, then the same three after restoring
the change. Same cwd matters — the r1 figure of "38 loaded" was taken in `$HOME`,
which is not a git repository, so gitsigns and friends never came up.

| | before | after |
|---|---|---|
| plugins in `lazy-lock.json` | 50 | 44 |
| loaded at startup | 41 | 35 |
| startup, 3 boots | 101.4 / 90.0 / 76.7 ms (median **90.0**) | 88.4 / 77.1 / 69.3 ms (median **77.1**) |
| build steps (`make`) | 1 | 0 |
| files deleted from `lua/` | — | 4 specs (`telescope`, `remote-nvim`, `nvim-notify`, `structlog`) + `ucw/log.lua` |

Removed: `remote-nvim.nvim`, `telescope.nvim`, `telescope-fzf-native.nvim`,
`session-lens`, `structlog.nvim`, `nvim-notify`.

**About that startup number.** r1 projected ~70 ms by summing the six plugins'
measured load times (≈23.3 ms) and called it an upper bound. It was: the median
moved ~13 ms, not ~23. Two reasons, both predicted — `snacks.picker` and
`snacks.notifier` now do work at startup that Telescope used to do lazily, and
lazy's per-plugin accounting bills a shared dependency to whoever `require`s it
first. **The run-to-run spread (±15 ms) is larger than the difference between
the two medians**, so three samples per side is the honest resolution here;
treat this as "somewhat faster", not as a precise 13 ms. The plugin and
loaded-plugin counts are exact and are the more meaningful figures.

`plenary.nvim` and `nui.nvim` stay: plenary is still required by gitsigns, octo
and neogit; nui by noice.

---

## 5a. Verification results (as built)

> **[r4]** Left as written. Everything below re-measured true — but the section
> is also the evidence for the acceptance review's R8: every item here verifies
> a *wiring* (does the key open a picker, does the notification reach snacks,
> does the healthcheck stop nagging), and none verifies a *behaviour carried
> over* (is the preview off, which delete does `<c-d>` do, what else does the
> new sweep rule close). §6's risk list named all three. The suite is now 112
> cases; see the review's §4.

Test suite: **108 cases, green ×2** after the last code change (and ×4 across the
phase; one run of the four failed on the pre-existing `child stuck in mode "r?"`
boot-prompt flake recorded in `docs/testing.md`, which is why the rule is to run
it twice).

Every new assertion in `tests/test_picker.lua` was reverse-verified — the change
it guards was reverted and **exactly** its own test went red:

| reverted | test that failed |
|---|---|
| `picker = 'lsp_references'` → a name that does not exist | `sources \| every ucw.lsp.actions picker entry is a real snacks source` |
| `views.notify.backend = 'snacks'` commented out | `notifications \| vim.notify routes through noice into the snacks notifier` |
| `notifier.enabled = false` | the two above (both, correctly — the flag is what `SnacksView:is_available()` reads) |
| a `nvim-telescope/telescope.nvim` dependency re-added to `octo.lua` | `removed plugins \| are not in the lazy spec any more` **and** `\| their modules are not requirable either` |

The suite also earned its keep before that: the first run of
`the keys bound to pickers all resolve` failed on `<M-S-f>` alone, because the
test ran the lhs through `nvim_replace_termcodes` first and `<M-S-f>` termcodes
to the byte sequence for `<M-F>`, which is not how which-key registered it.
Every other key passed. Fixed in the test, noted in a comment there.

**V1 — every picker key pressed, in a real TUI.** `<C-p>` → Files (3/3 with
preview), `<M-S-f>` → Grep, `<M-f>` → Lines, `<leader>Th` → Command History,
`<leader>bb` → Buffers, `<leader>ss` → Sessions (16 entries, `~` shortening,
`(legacy)` markers), `<leader>nn` → Noice, `<leader>nh` → Notification History.
`<Esc>` from insert closes the picker and returns the cursor to the window it
was opened from (checked by typing afterwards and seeing the text land in the
original buffer, not by reading state back — see the observation note below).

**V3 — the seven LSP pickers against a real `lua_ls`.** `<leader>l0` → Lsp
Symbols, `<leader>lW` → Lsp Workspace Symbols, `<leader>le` → Diagnostics
Buffer, `<leader>ld` → Lsp Definitions (2 results, previewing the right file),
`<leader>lr` → Lsp References. `<leader>lt` and `<leader>lD` correctly report
`No results found for lsp_type_definitions` / `lsp_implementations` for a Lua
local — which is itself end-to-end evidence for the notification chain, since
that message travels picker → `vim.notify` → noice → snacks. `:messages` clean
throughout.

**V4/V5 — session round trip, against a baseline captured before any change.**
Before: 6 windows (neo-tree, alpha, beta, notes, help, terminal) → save → 4
buffers recorded → restore → 4 windows. After: identical, 4 windows and 4 listed
buffers, no drawer, no empty help split. Getting there required W1 below.

**V6 — `restore_shortmess`: see W2.** After removal, `&shortmess` is
`lCtsoFOT` both before and after a restore. Before the change it went
`tOFToslC` → `ltToOCF`.

**V7 — notifications.** Toast renders in `compact` (3 lines, icon and title
inlaid in the top border) against nvim-notify's 5. `:Noice all` shows all four
message kinds: the startup `msg_show`, three `notify.*` entries with title and
level, `msg_show.echomsg`, and `msg_show.emsg` carrying `E492: Not an editor
command`. `:Noice history` shows the notifications alone. The stated pain point
is fixed.

**V8 — `:checkhealth`.** `auto-session`: the "You have old config names" block
is gone, and it reports `Selected picker: snacks`. `noice`: `✅ snacks.nvim is
installed`, `✅ vim.notify is set to Noice`; its two remaining warnings are
missing `regex`/`bash` treesitter parsers, which is the no-`tree-sitter`-CLI
situation on this machine, not this phase.

### W1 — `close_unsupported_windows` does not run on the manual-save path

r1's §1.3 concluded that auto-session's built-in sweep had been running
alongside `close_aux_windows` all along, and that the hook could therefore
delegate to it. **Half true.** `close_unsupported_windows` is called from
`AutoSession.auto_save_session()` and nowhere else (`auto-session/init.lua:339`)
— that is the `VimLeavePre` autosave path. `save_session()`, which is what
`:AutoSession save` and `<leader>sc` reach, never calls it.

Consequence, measured: after trimming the hook to help + diffview, a manual save
left the neo-tree drawer open, `mksession` recorded its window, and the restored
layout came back with **5 windows instead of 4**. Caught by V4 only because a
baseline had been captured *before* the change — the restored session looks
perfectly plausible on its own.

Fixed by keeping the sweep, but replacing the hand-maintained filetype list with
upstream's own predicate (not a readable file, not a terminal), plus upstream's
"never close the last window of the last tab" guard. Re-verified: 8 windows
before save → 4 after → 4 restored, matching baseline exactly.

> **[r4]** And that swap had a second edge nobody looked at. The question asked
> was "does upstream's rule still close what ours closed"; the question not
> asked was "**what does upstream's rule close that ours never did**".
> `filereadable(name) == 0` is true of a **file you have not written yet**, so a
> new-file window — with unsaved content in it — was closed on every *manual*
> save, and `mksession` records such a buffer perfectly well. Upstream can
> afford the coarser rule because it only sweeps on `VimLeavePre`, which is the
> very asymmetry W1 is about; this hook also runs interactively. Fixed by
> exempting a named `buftype == ''` buffer. See the acceptance review, R2.

The lesson is the r1 method's, not the row's: *"the option defaults to true"* was
read off the config table and never traced to a call site. Phase 3's rule — a
static read is not a measurement — applied to an option instead of a function.

### W2 — `restore_shortmess` was not a dead workaround, it was an active bug

D6 framed this as "probably dead, delete on evidence". The evidence came out
differently: `set shortmess&` resets to Neovim's **factory default**, which
discards `lua/ucw/options.lua:17`'s `shortmess:append('s')`. Measured across a
restore: `tOFToslC` (has `s`) → `ltToOCF` (no `s`). So every session restore
silently turned the "search hit BOTTOM, continuing at TOP" message back on, and
had done for as long as the hook existed.

Meanwhile the session file needs no help at all — `mksession` brackets its own
`set shortmess+=aoO` with a save/restore pair (lines 11-12 and 598 of the
generated file). There was never anything for the hook to fix.

### Observation-method notes (cost real time, worth recording)

* **`vim.fn.bufname(0)` is not "the current buffer".** `bufname()` takes a buffer
  *number*, and 0 is not a valid one, so it returns `''` — which reads exactly
  like "the current buffer is unnamed". Use `bufname('%')`.
* **An RPC probe runs in whatever buffer is current, and a just-closed picker is
  still current.** `maparg('<M-f>', 'n')` came back as snacks' `toggle_follow`
  and looked like a global-mapping regression; the probe was running inside a
  lingering `snacks_picker_input` buffer (`buftype=prompt`), where that mapping
  is legitimately buffer-local. Probe `maparg().buffer` before believing a
  keymap reading.
* **Sending keys with no gap between pickers types into the previous one.**
  Several "the key did nothing" results were a picker still open, or the editor
  still in insert mode, swallowing the next batch — once producing a blink
  snippet expansion (`date` → `04/08/2026`) inside a picker prompt that looked
  briefly like blink leaking into picker inputs. It does not: blink's default
  `enabled` is `vim.bo.buftype ~= 'prompt'` and the picker input is a prompt
  buffer, verified directly. Wait on the actual condition (no floating windows)
  between probes rather than on a duration.
* **The three notifier-style tmux sessions had nothing in them by the time the
  user attached.** The probe notifications had a 60 s timeout and had long
  expired; the captures in this document were taken seconds after boot. A TUI
  session meant for a human to look at later needs its content to be persistent,
  not a toast.

---

## 6. Risks

* **The buffers picker is the one with real behaviour attached** (D5). If the
  custom `<c-d>` action is not wired correctly it will silently fall back to
  snacks' own `bufdelete` and quietly change window-layout behaviour — the exact
  shape of Phase 4's F2/F3, "scope changed during the move". V1 must press the
  key, not check that it is bound.
* **`ucw.lsp.actions` gaining a third action kind is a seam**, and Phase 3's
  lesson was that every finding lived on a seam between two owners. The `picker`
  kind must be resolved at press time like `lsp` is, and `M.wk`/`M.rhs`/`M.call`
  must all agree about it — three functions, one new branch each.
* **Deleting `remote-nvim` is the one irreversible-feeling step.** It is
  recoverable (one spec file, in git), but if the user does want remote editing
  back later, the replacement is a separate decision, not a revert.
* **`close_unsupported_windows` has been running all along**, which means the
  session behaviour users have lived with is the *union* of both mechanisms.
  Removing our half is a behaviour change even where the two overlap, because
  ordering differs (ours runs from `pre_save_cmds`, theirs from
  `init.lua:339`). V4's before-baseline is what makes this checkable.
* **noice self-describes as "Highly experimental"** and is built on
  `vim.ui_attach`. Unchanged from today — it is already running — but the phase
  increases reliance on it by making it the only path to message history.

---

## 7. Observed, out of scope

* `ucw.utils.buf_kill` (~110 lines) substantially overlaps `Snacks.bufdelete`,
  which is now a first-class dependency. Ours is jumplist-aware and theirs is
  not, so this is a real behaviour question, not a cleanup — and it is a
  keymap/behaviour decision, which makes it Phase 9's.
* `lua/ucw/plugins/lsp_progress.lua` rebuilds and re-applies the whole lualine
  config on `LspAttach` (3–12 ms). `snacks.notifier` has a documented
  `LspProgress`-driven pattern that would remove the plugin, but the statusline
  is explicitly "leave as-is this round" in the plan file.
* `~/.local/share/nvim/telescope_history` and `~/.local/share/nvim/nvimd.log`
  are leftovers from removed systems. Harmless; sweep them when convenient.
* `AGENTS.md`'s "Fast boot" bullet still describes `_G.nvimctl` and unit graphs.
  Phase 10.
* The blink floating window left behind after RPC-driven cmdline input (Phase 4
  §8) still reproduces. Still the completion phase's.
