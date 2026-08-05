# Phase 5 acceptance review

Reviewed: commit `9618f17` ("Phase 5: one picker, one notifier, and a plugin
that was never used") against `docs/design/phase5-session-notify-picker.md`
(r3) and the plan file's Phase 5 row.

**Verdict: do not accept as-is.** Two behaviour regressions that are live today
(R1, R2), one half-finished carry-over of the single behaviour the design doc
named as the riskiest thing in the phase (R4), a key nobody pressed (R3), and
three documentation/config items that contradict the phase's own conclusions
(R5–R7). R8 is why none of R1/R2/R4 showed up: the suite grew a picker test that
checks *names*, and none of the three behaviours the design doc called out as
the ones to press a key for.

Everything the design doc's §5a claims about the notification chain, the plugin
deletions, the session command names and the option renames **re-measured
true**. The two falsified-claim writeups (W1, W2) are correct and are the best
part of the phase. The problem is not the conclusions; it is that the sweep for
*what else changed* stopped at the things that were being deliberately changed.

Same rule as the design doc: everything below marked **measured** was produced
on this machine (Neovim 0.12.3) against the real config, via `just ci` and
`scripts/tui-drive.sh`. Nothing here is inferred from reading the diff.

---

## 1. Findings

| # | Finding | Kind | Severity |
|---|---|---|---|
| R1 | The buffers picker **still shows a preview**. `preview = false` is not a source-level snacks option; it resolves to the default file previewer | regression vs Telescope, silently ignored config | **major** |
| R2 | The session sweep now closes the window of any file **that does not exist on disk yet** — a new file you have not written | undeclared scope change, live on `<leader>sc` | **major** |
| R3 | `ucw.keys.actions.clear()` is bound to **`<Esc>` in normal mode**, which nothing in the phase pressed, and its own comment says `<C-l>`. The port is sound; the audit trail is not | verification gap + misleading comment | minor |
| R4 | The buffers picker has **three** delete keys; only `<c-d>` uses the jumplist-aware delete D5 is about. `<c-x>` and `dd` still call snacks' own | half-finished carry-over | medium |
| R5 | `auto-session.lua`'s **header comment still states the claim W1 falsified**, and points at the legacy `:SessionSearch` | in-code doc contradicts the file below it | minor |
| R6 | `winblend` is carried over onto the **input window only**; Telescope applied it to every picker window | incomplete port | minor |
| R7 | `scripts/tui-drive.sh`'s header still advertises `send ':Telescope find_files<CR>'`; `docs/tui-observation.md`'s snippet still calls `nvimctl:start(...)` | stale docs, adjacent to lines this phase edited | minor |
| R8 | Nothing in the suite covers the buffers-picker preview, the custom delete action, or `close_aux_windows` at all | test gap — the reason R1/R2/R4 are green | medium |

---

### R1 — the buffers picker still previews (major)

`snacks.lua` carries Telescope's `pickers.buffers.previewer = false` across as:

```lua
sources = {
  buffers = {
    -- Telescope had `previewer = false` here: the file is already open,
    -- there is nothing to preview that the buffer list does not say.
    preview = false,
```

`preview` at source level is typed `snacks.picker.preview|string` — *a previewer
function or a preset name*, not an on/off switch. `snacks/picker/config/init.lua:198`:

```lua
local preview = opts.preview or Snacks.picker.preview.file
```

`false or X` is `X`. So the value is discarded and the buffers picker gets the
**default file previewer**. The switch snacks actually offers is a *layout*
one — `layout = { preview = false }`, which `config/init.lua:245` turns into
`layout.hidden = { "preview" }`.

**Measured**, `<leader>bb` in a real TUI:

```
lua/ | lua/ | PREVIEW:lua/ | snacks_picker_list/nofile | snacks_picker_input/prompt | ...
opts.preview = false        resolved_layout.hidden = {}
```

and the screen capture shows a full preview pane titled `options.lua` beside the
buffer list. This is the same class as Phase 3's silent-dead-key: a config value
that is neither honoured nor rejected. It is also the *one* carry-over in §3.1's
table that the design doc did not mark "assert, don't restate" — and V1 pressed
`<leader>bb`, saw a picker, and recorded "→ Buffers" without looking at what was
in the window next to it.

### R2 — the session sweep now closes windows for files that do not exist yet (major)

W1 is right that the sweep had to stay. What went unexamined is that its *rule*
changed in both directions. The review of the new predicate asked only whether
it still closes what the old one closed (drawers, tool windows, help). It also
closes things the old one did not:

```lua
return buftype ~= 'terminal' and vim.fn.filereadable(A.nvim_buf_get_name(buf)) == 0
```

`filereadable` is false for a **brand-new file you have not written yet**. The
old rule closed floats, four hard-coded filetypes and `buftype == 'help'`; a
normal file buffer never matched it, existing or not.

**Measured**, three windows, the middle one a new file with unsaved content:

```
BEFORE: options.lua | ucw-brand-new-file-probe.txt | utils.lua
AFTER : options.lua | utils.lua
        buf=43 modified=true lines={ "unsaved work" }
```

The buffer survives (nothing is lost), but the window vanishes from under you
the moment you press `<leader>sc`, and the restored layout no longer has it. And
it is worth recording that this is not "what upstream does anyway": `mksession`
records such a buffer perfectly well —

```
badd +0 /tmp/ucw-brand-new-file-probe.txt
if bufexists(...) | buffer ... | else | edit /tmp/ucw-brand-new-file-probe.txt | endif
```

— so the window was carrying real, restorable state. Upstream can afford the
coarser rule because it only ever runs on the `VimLeavePre` autosave path, where
nobody is watching. This config runs the same rule from `pre_save_cmds`, i.e.
also on the interactive path, which is exactly the asymmetry W1 discovered and
then did not follow through.

This is Phase 4's F2/F3 shape once more — scope quietly changed while moving
code — with the twist that here the move was *from our own rule to upstream's*,
which reads like a de-risking step and is not one.

**Accepted, deliberately, not fixed:** `acwrite` buffers (`fugitive://`,
`octo://`, `diffview://`) are also newly swept. The old rule kept most of them,
but a session cannot restore them into anything useful, and upstream closes
them. Recording it here so it is a decision rather than another R2.

### R3 — `M.clear` runs on `<Esc>`, and nothing in the phase pressed `<Esc>` (minor)

**This review got R3 wrong twice before getting it right, and both wrong
versions are instructive, so they are recorded rather than deleted.**

§1.4 lists three call sites that "reach around `vim.notify` to nvim-notify
directly and would break", the first being `keys/actions.lua:144` — `M.clear`.
Phase 5 rewrote its body from `require('notify').dismiss()` to
`require('noice').cmd('dismiss')`.

**Wrong reading #1: "it is dead code."** `grep -rn` for `clear()`,
`keys.actions` and `.clear()` across `lua/` and `tests/` found the definition
and no caller, and `maparg('<C-l>', 'n')` came back as Neovim's built-in
(`desc = ":help CTRL-L-default"`, `sid = -8`). Two independent checks, both
negative, and the function's own comment ("Like the default Ctrl-L") pointed
at the key that had just been ruled out. So the fix deleted it — and the config
would not boot:

```
E5113: Lua chunk: [string "vim/keymap"]:60: rhs: expected string|function, got nil
        /home/aetf/.config/nvim/lua/ucw/keys.lua:32: in main chunk
```

`lua/ucw/keys.lua:32` is `vim.keymap.set('n', '<esc>', actions.clear, …)` — a
**function reference through a local alias, with no parentheses and no
`keys.actions` on the line**. Every grep pattern used missed it, and the
comment sent the `maparg` probe to the wrong key. This is the config's own
recorded rule ("a static read is not a measurement") failing on the negative
case: *finding* nothing is not the same as *there being* nothing, and the
cheapest disproof — delete it and boot — was available the whole time.

**Wrong reading #2: "then it wipes the message history on every Escape."**
`require('noice').cmd('dismiss')` → `Router.dismiss()`, whose first line is
`Manager.clear()`, which does `M._messages[message.id] = nil` for every message.
On the most-pressed key in normal mode that would empty the very store
`<leader>nn` and `<leader>nh` were added to make browsable — a headline feature
of the phase destroyed by pressing Escape. Written up, fixed, and then
**measured, which disproved it**: noice keeps *two* stores
(`manager.lua:11-14`), and `clear()` empties only the live `_messages` set.
`:Noice`, `Snacks.picker.noice()` and the history pickers all read `_history`,
which nothing in that path touches.

```
3 messages held -> <Esc> -> noice history = 3, snacks history = 2
reverse check, calling require('noice').cmd('dismiss') directly: 3 -> 3
```

**What is actually true.** The port is behaviourally sound. What is wrong is
that nobody could have known that from this phase: `<Esc>` in normal mode is not
in §5a's verification, `M.clear` is described there as an nvim-notify call site
rather than as what Escape does, and the comment on the function names the wrong
key. It is also a genuine, undeclared widening — `notify.dismiss()` hid toasts,
`noice.cmd('dismiss')` takes down every noice view and clears the live message
set. Benign on `<Esc>`, arguably what "clear things" should mean, but it was
never stated and never pressed.

`tests/test_keys.lua` cannot catch any of this: its guard is "no which-key entry
carries a rhs in its `desc`", and this key is not a which-key entry at all.

### R4 — three delete keys in the buffers picker, one of them ours (medium)

D5 is the design doc's own "this is the risky one": keep
`ucw.utils.bufdelete`'s jumplist preference rather than snacks' plain
`Snacks.bufdelete`, and *press the key* to check it. The custom action is wired
correctly — **measured**, `<c-d>` deletes through `ucw_bufdelete` and the buffer
list goes `1:utils.lua,8:options.lua` → `1:utils.lua`.

But snacks' buffers source ships **two more** delete bindings, and the override
only replaced the one Telescope happened to use. **Measured**, resolved config
for `source = 'buffers'`:

```
input <c-d> = { "ucw_bufdelete", mode = { "n", "i" } }   -- ours
input <c-x> = { "bufdelete",     mode = { "n", "i" } }   -- snacks'
list  dd    = "bufdelete"                                 -- snacks'
```

So the picker has one deliberate, jumplist-aware delete and two that silently
are not — in the same window, on adjacent keys. §3.1's own table named
`win.list.keys` as part of the port and it was not carried over. Under Telescope
this could not happen: there was only ever the one binding.

### R5 — the file's header comment still asserts what W1 disproved (minor)

`auto-session.lua` opens with:

> The hooks are what is *left* after checking each one against what
> auto-session already does by itself. `close_unsupported_windows` defaults to
> true, **so it has been running all along underneath the old hook**: it closes
> every window whose buffer is not a readable file and is not a terminal,
> **which covers the drawer/tool/float sweep** `close_aux_windows` used to do by
> hand.

Thirty lines below, the comment on `close_aux_windows` says the opposite, and is
the correct one:

> This cannot delegate to auto-session's `close_unsupported_windows`, even
> though that option is on. Measured: it is called from
> `AutoSession.auto_save_session()` only …

The header is r1's falsified paragraph, left in place when the function comment
was rewritten for r3. Same file, two contradictory claims, and the wrong one is
the one you read first — which is precisely the failure mode W1 is a writeup
about.

The same header also credits `session-lens`' replacement to "auto-session's own
`:SessionSearch`", while the entire third layer of staleness this phase found is
that `:SessionSearch` is the *legacy* name and `legacy_cmds = false` now removes
it. `which-key.lua` says this correctly.

### R6 — `winblend` reaches only the input window (minor)

Telescope set `defaults.winblend`, which applied to the whole picker. The port
sets `picker.win.input.wo.winblend` only, so under a GUI the list and preview
windows would stay opaque while the prompt is translucent. §3.1's own table
named `win.input` / `win.list` / `win.preview`.

No effect on this machine (`is_gui()` is false, and 0 is snacks' default), which
is why the comment says "carried over rather than verified" — but half a
carry-over is worse than none, because the next person reads it as done.

### R7 — stale docs adjacent to the lines this phase fixed (minor)

* `scripts/tui-drive.sh:15` — the script's own usage header still says
  `scripts/tui-drive.sh send ':Telescope find_files<CR>'`. `docs/tui-observation.md`
  documents the same script and *was* updated in this commit; the script was not.
* `docs/tui-observation.md:53` — `child.lua([[nvimctl:start('target.tui')]])`,
  an engine removed in Phase 1, sits on the line directly above the one this
  commit edited. (The `vim.loop.sleep(300)` under it also contradicts the
  project's own no-sleep rule; left as-is here, flagged for whoever rewrites
  that snippet properly.)

### R8 — the test gap that let R1, R2 and R4 through green (medium)

`tests/test_picker.lua` is good at what it does: names resolve to real sources,
deleted plugins are gone from the spec and unrequirable, `vim.notify` really
reaches snacks through noice. Every assertion was reverse-verified. **Measured**,
the suite is 108/108 green (run 2 of 2; run 1 hit the pre-existing
`child stuck in mode "r?"` boot-prompt flake on `test_picker`, documented in
`docs/testing.md`).

What it does not touch is every behaviour the design doc itself flagged as
risky:

* §6 risk 1 (D5, the buffers picker "is the one with real behaviour attached") —
  no assertion on the preview, none on which action `<c-d>`/`<c-x>`/`dd` map to.
  R1 and R4 both live here.
* `close_aux_windows` has **no test at all**; V4/V5 were manual TUI runs. R2
  lives here.

The pattern across three phases now: the new test guards the thing that was
being *changed on purpose*, and the finding lands on the thing that changed as a
side effect. Phase 3's was "test the path that belongs to nobody", Phase 4's was
"test the path that is not the main one"; Phase 5's is **test the behaviour you
said was the risky one, not the wiring that produces it**.

---

## 2. Re-measured and confirmed true

Recorded so the next round does not re-do it:

* **Plugins**: `lazy-lock.json` has 44 entries; no `telescope*`, `nvim-notify`,
  `structlog.nvim`, `remote-nvim.nvim` or `session-lens` in the lockfile, in
  `lazy.core.config.plugins`, or on disk under `~/.local/share/nvim/lazy/`.
* **Notification chain**: `vim.notify == require('noice.source.notify').notify`,
  `Snacks.config.notifier.enabled == true`, `style = 'compact'`,
  `timeout = 3000`, `views.notify.backend == 'snacks'`.
* **`<leader>nd`** really dismisses: 1 floating window → 0. `noice.commands.cmd`
  does have a `dismiss` entry (`Router.dismiss()` → each view's `dismiss` →
  `SnacksView.dismiss` → `Snacks.notifier.hide()`).
  *Note for later:* `noice.commands.cmd` **falls back to `history()` for an
  unknown name** rather than erroring, so a typo there would open the wrong
  window rather than fail. Correct today.
* **Session commands**: `:AutoSession` exists; `:SessionSave`, `:SessionRestore`,
  `:SessionSearch`, `:Autosession` are all gone. `save`, `restore` and `search`
  are all real subcommands (`getcompletion('AutoSession ', 'cmdline')`).
* **`<Esc>` in a picker** closes it from insert mode and leaves 2 windows.
* **Dropping the "close all floats" rule is harmless**, which the design doc
  asserted and did not check: `mksession` does not record floating windows at
  all. Verified by opening a float on a real file, running the sweep (it
  survives — a behaviour change), then `mksession` and grepping the output: no
  window entry, no `badd`, nothing. Non-issue, now on the record as one.
* **`ucw.lsp.actions`' `picker` kind**: all seven names resolve to real
  `snacks.picker` sources, `M.call` type-checks before calling, and unknown
  names really do come back `nil` rather than raising.

---

## 3. Fixes applied

Commit: see `git log` following this document.

| # | Fix |
|---|---|
| R1 | `sources.buffers.preview = false` → `layout = { preview = false }`, the option snacks actually reads |
| R2 | `unsupported_window` exempts a named, normal (`buftype == ''`) file buffer whether or not the file exists yet |
| R3 | No behaviour change (the port is correct). The comment on `M.clear` now says which key it is on and why the wider dismiss is safe; `keys.lua:32` grew a `desc` and a note that a grep will not find this binding |
| R4 | `<c-x>` and `dd` in the buffers source point at `ucw_bufdelete` too |
| R5 | `auto-session.lua`'s header rewritten to say what the file below it actually does |
| R6 | `winblend` also on `win.list` and `win.preview` |
| R7 | `tui-drive.sh` header updated; the `nvimctl:start` line in `docs/tui-observation.md` replaced with the lazy.nvim equivalent |
| R8 | `tests/test_picker.lua` grows a `buffers picker` group (preview hidden, all three delete keys resolve to `ucw_bufdelete`) and a `session hooks` group (a not-yet-written file's window survives the sweep, a `nofile` drawer window does not). Each reverse-verified |

---

## 4. Verification of the fixes

Same rule as the phase itself: every new test reverse-verified, `just ci` twice.

**Suite: 112 cases, green ×2** (108 + 4). No flake this time.

**Reverse verification** — revert the fix, and *exactly* its own test goes red,
nothing else:

| reverted | test that failed |
|---|---|
| `layout = { preview = false }` → `preview = false` | `buffers picker \| has no preview window` |
| the `<c-x>` and `dd` overrides removed | `buffers picker \| every delete key goes through ucw.utils.bufdelete` |
| the `buftype == ''` exemption removed from `unsupported_window` | `session hooks \| a not-yet-written file keeps its window` |
| `unsupported_window` short-circuited to `return false` | `session hooks \| a nofile drawer window does not` |

**Live, in a real TUI** (`scripts/tui-drive.sh`, against the real config):

* **R1** — `<leader>bb`: `snacks_picker_preview` windows = **0**;
  `config.layout(get{source='buffers'}).hidden` = `{ "preview" }`.
* **R4** — resolved buffers config now reads
  `<C-D> = ucw_bufdelete`, `<C-X> = ucw_bufdelete`, `list dd = ucw_bufdelete`.
  (Note for the test: snacks' `fix_keys` **normalises key names on merge**, so
  `<c-d>` is stored as `<C-D>`; the first version of the assertion looked up the
  spelling as written and silently found `nil` on two of three keys — the same
  shape as Phase 5's own `<M-S-f>`/`nvim_replace_termcodes` note. It now goes
  through `Snacks.util.normkey`.)
* **R2** — four windows (`options.lua`, an unwritten `/tmp/…2.txt` with unsaved
  content, `utils.lua`, a `nofile`/`neo-tree` drawer) → after `pre_save_cmds`:
  the three file windows survive, the drawer is gone. A `:help` window is still
  swept (`win_is_valid` → false), i.e. the residue W1 kept is intact.
* **R3** — three messages held by noice; `<Esc>` → noice history still 3, snacks
  history 2. Direct call to `require('noice').cmd('dismiss')`: 3 → 3.
* **R6** — `winblend` now resolves on all three windows (`{0, 0, 0}` here, since
  `is_gui()` is false — still the documented no-op, now a complete one).

**Deliberately not changed:**

* `acwrite` scheme buffers stay swept (see R2's note).
* `<leader>nd` and `<Esc>` now do the same thing. That is a keymap question, and
  keymaps are Phase 9's.
* `docs/tui-observation.md`'s `vim.loop.sleep(300)` was replaced with a
  `vim.wait` on a condition while that snippet was being fixed anyway; the wider
  nvimd cleanup in `AGENTS.md` ("Fast boot", the `units/thirdparty/…` templates
  pointer) stays Phase 10's, as §7 of the design doc already says.
