# Phase 9.5 — trial-period tuning

Status: **as-built record, written as the changes landed (2026-08-22/24).**

Phase 9 (`phase9-keybindings.md` r3) ended with "real-session trial runs next".
This is that trial: the config in daily use, each thing that turned out wrong
fixed in its own commit with its own guard. It is a *design* document rather
than a changelog because several of the changes rest on mechanisms that are not
obvious from the code they touch, and the next person to add a `<leader>` key,
a bracket pair or an autocmd needs them.

**Where this supersedes an earlier phase document, that document now says so
inline and points here.** Phase 10 (the as-built rewrite of `AGENTS.md` and
`docs/architecture.md`) is what folds all of this into one current description;
until then, a phase document is the record of its own phase, and this one is
the record of what the trial changed afterwards.

T1–T5 reopen no Phase 9 decision: what the trial found there was one duplicate
door, a presentation layer nobody had looked at as a whole, and two editor
behaviours that were quietly broken. T6 and T7 each reopen one — D2's "no jump
key for snacks.words", and which view `<CR>` opens on a commit — and each
states the rule its family now follows. T8 reopens nothing either: it is a
notification the trial found saying the same thing four times. T9 reopens T6's
own rule 1, and says where the line between the bracket family and a native
vocabulary falls. T10 is not a keybinding at all: two gates and one
notification that had each been failing long enough to read as scenery. T11
closes the one thing T10 left open.

## 1. T1 — `<leader>e`/`E` dropped (supersedes §2.5, §3)

D5 gave the explorer leader-space duplicates of `\` (toggle+reveal) and `|`
(focus), on the theory that `e` is the community letter for a file tree and it
had just been freed by iron's move to `<leader>r`.

In use the hands never went there: `\`/`|` predate the leader keys and are what
the muscle memory reaches for. Two doors to one action, and the door nobody
opens is the one costing a `<leader>` letter and two rows in the popup that is
always one keypress away. Dropped — the same "one door per thing" call D3 made
when it declined `<leader>fb` next to `<leader>bb`.

`<leader>e`/`E` are free again. `\` and `|` are unchanged and are now the only
door.

## 2. T2 — one convention for `<leader>`'s first level

The first level had assembled itself over nine phases and read like it: group
labels mostly lowercase but `REPL` and `toggles/UI` not, icons present on some
entries and absent on others, and visual mode showing `c ➜ +2 keymaps` where
normal mode showed a name.

Three mechanisms, none of them visible in the code that suffers from them:

- **which-key picks icons by matching keywords against the *description***
  (`which-key/icons.lua`'s `rules`). It is luck, not design: `REPL` matched no
  rule and rendered blank, while `Go to alternate buffer` and `Buffer-local
  keymaps` both matched the `buffer` rule and came out as file icons.
- **`wk.add` defaults to mode `n`.** Group *headers* were therefore
  normal-mode-only while their members (`<leader>ca`, `<leader>sw`,
  `<leader>r*`, …) existed in visual too, which is the whole of the
  `+N keymaps` rendering — the members were never missing.
- **An entry with an `icon` and nothing else merges into the node the real
  mapping already made.** That is how `<leader>n`, whose key is a lazy
  `keys =` entry in `snacks.lua`, gets an icon from `which-key.lua` without
  its key moving. (It is also the shape the Phase 3 `g[`/`g]` bug had — a
  label for a key with no rhs — used deliberately here.)

Resolved rules, asserted in `tests/test_keys.lua` rather than trusted:

1. **Group labels are lowercase nouns** naming the space; proper nouns keep
   their own spelling (`Lazy`, `GitHub`). `REPL` → `repl`,
   `toggles/UI` → `toggle/ui`.
2. **Leaf labels are Sentence-case verb phrases** (`Plugin manager (Lazy)`).
   The case then carries the same information as the `+` prefix: group vs
   action.
3. **Every first-level entry names its own icon.** No first-level row is left
   to keyword matching.
4. **Group headers register for `n` and `x`.** Headers whose subtree has no
   visual-mode member simply do not draw there.

## 3. T3 — labels for keys this config does not own

The same failure mode, one layer down, and the reason `v` opened onto a wall of
`Lightspeed_f`, `MatchitVisualForward)`, `help v_star-default`, a literal
`<Esc><Cmd>w<CR>` and nine blank rows:

> **which-key renders a mapping's `desc`; when there is none it falls back to
> displaying the rhs** — and to nothing at all when the rhs is a Lua function.

This is the mirror image of the bug `tests/test_keys.lua` has guarded since
Phase 8 (a rhs written *into* a desc), and that guard could not see it: it
scans descs that exist. Both halves are covered now, and the new guard
immediately found a mapping of this config's own that the by-hand pass had
missed (`S` labelled for visual but not normal).

Two kinds of fix, and the difference matters:

- **Keys this config creates get a real `desc` at the definition site**
  (`ucw.keys`): `<c-s>` in three modes, the two mouse side buttons, `]q`/`[q`,
  `0`/`^`/`p`/`j`/`k`, the comment shortcut, terminal escape. A missing `desc`
  here is a defect, not a presentation choice.
- **Keys owned by a plugin or by Neovim get a label in `which-key.lua`** —
  lightspeed, neoscroll, matchit, and Neovim's own visual `*`/`#`/`@`/`Q`,
  whose descs are deliberately written as help tags (`:help v_star-default`):
  fine for `:map` to print, a poor row in a popup.

Why those labels are central rather than in each plugin's spec, which is where
Phase 8 D1 put a plugin's *keys*: a spec that labels its own keys has to
`require('which-key')`, and which-key is `cond`-gated off under vscode-neovim
(D9), where a bare require of a disabled plugin throws. Group headers were
centralised for exactly this reason; labels follow them.

**Labels only — no rhs.** Nothing is mapped or remapped, and the keymap
snapshot does not move. Modes are per key, matching where each mapping really
exists, since a label on a mode with no mapping is the `g[`/`g]` bug in popup
form. Verified in a real TUI that the operator-pending labels did not eat their
operators: `dfb`, `dtm` and lightspeed's `dzga` all still take their motion.

`gq`/`gw` are labelled here too. This is the one place which-key's `operators`
preset was wanted, and it stays off — it labels `d`/`c`/`y`/`hjkl`, keys nobody
looks up, on triggers that fire mid-operator — and it has no `gq` entry anyway.
The descs spell out the distinction that actually bites: `gq` runs
`'formatexpr'`, which Neovim's LSP client sets on attach whenever the server
offers range formatting and `ftplugin/tex.lua` sets by hand, while `gw` ignores
it (`:h gw`) and always wraps at `'textwidth'`.

**Left alone, deliberately.** `+N keymaps` on native prefixes (`g`, `z`, `[`,
`]`) is which-key naming an unnamed prefix honestly, not junk. Neovim's own
normal-mode defaults (`&`, `Y`, `<C-L>`, `<BS>`, `<CR>`) stay unlabelled and
are pinned by name in the guard's expectation list, so a *new* unlabelled
mapping still fails it. nvim-ufo's `zR`/`zM` are unlabelled too and invisible
to the guard: ufo is `cond = is_full_ui` and the test child is headless.

## 4. T4 — diagnostic virtual lines default to off (supersedes phase 4 §3.2)

Phase 4 moved lsp_lines.nvim's default into `ucw.options` as
`virtual_lines = { current_line = true }` in the full UI. In use it is too
expensive for what it gives: `virtual_text` already puts the message on screen,
and the extra two or three lines reflow everything below the cursor on every
cursor step.

Default is now `false` everywhere; `<leader>uv` (D4's toggle, unchanged) is what
turns it on for the rare diagnostic `virtual_text` truncates. The target branch
went with it — it carried lsp_lines' `cond = is_full_ui`, and off everywhere
subsumes off in the embedded hosts — which also retired the "off in the
embedded contexts" test case, since it could no longer fail for the reason it
claimed to cover.

## 5. T5 — files changed on disk are actually reloaded

`'autoread'` was already on and had been since the initial commit. It only
decides what happens *when* nvim notices; nvim notices when something runs
`:checktime`.

**The root cause was outside this repo.** Neovim core runs `:checktime` on
buffer entry and on terminal focus by itself — both measured with
`nvim --clean -c 'set autoread'`, no config involved: a `:bnext`/`:bprev`
round-trip picks up an external rewrite, and so does a focus-in sequence. But `~/.config/tmux/tmux.conf` had
`set-option -g focus-events` *with no value*, which tmux reads as **off**
(`show-options -g focus-events` printed `off` on the running server), so the
terminal's focus reporting stopped at tmux and core's path was dead. Fixed
there (yadm `9098ba4`); with a client attached, switching tmux windows away and
back now reloads a stale buffer with no keypress at all. A detached session
sends no focus events at all, which is its own way to get a false negative when
testing this.

What remains for this config is the case core does not cover: a buffer you are
sitting in, in a focused window, while a formatter or a `git checkout` rewrites
the file. `ucw.extras` puts `:checktime` on `CursorHold`/`CursorHoldI` (plus
`FocusGained`/`BufEnter`/`TermLeave`). `CursorHold` is the idle hook, not a
delay standing in for an event: nvim has no "file changed" notification to hook
— `FileChangedShell` fires *from* the check — so the check must be scheduled,
and `'updatetime'` (300ms) is the interval the editor already keeps for that.

Measured, after the first version of this got two of them wrong:

| case | `FileChangedShellPost` | `v:fcs_reason` | what happened |
|---|---|---|---|
| file rewritten, buffer clean | fires | *empty* | reloaded |
| file deleted | fires | `deleted` | nothing reloaded; nvim raises `E211` |
| file rewritten, buffer modified | **does not fire** | — | W12 prompt, buffer kept |

So the "Reloaded from disk" notice is skipped for `deleted` (it was announcing a
reload that had not happened, next to nvim's own true message), and the claim
that unsaved work is never at risk is a measurement rather than an argument.

Both autocmd groups are gated on `is_full_ui()`. A reload rewrites the buffer's
text, which is precisely what `conform.lua`'s `format_on_save` declines to do in
the embedded hosts and for the same reason: vscode-neovim mirrors documents
VSCode owns and reloads itself, and firenvim's buffer is a browser textarea with
no file behind it.

## 6. T6 — one grammar for "previous / next"

Three unrelated shapes had accumulated for the same idea, and the config's own
keys were the ones out of line:

- `[`/`]` + a category letter, direction in the **prefix**, capital = first /
  last. Neovim 0.11 shipped a whole unimpaired-style set in this shape (`[q`,
  `[l`, `[b`, `[a`, `[t`, `[d`, `[<Space>`, `[n` in visual), gitsigns' `[c`/`]c`
  matches it, and it is the only shape that scales: a new category is a new
  letter, and the direction needs no thought.
- `g` + a character, direction in the **suffix** or in the case: `g[`/`g]` for
  diagnostics (this config's own).
- A dedicated key pair: `<Tab>`/`<S-Tab>`, `<C-o>`/`<C-i>`, `n`/`N`, `;`/`,`.

The rules, stated once so the next binding has somewhere to look:

1. **`[`/`]` + a letter is the only spelling of previous / next.** Direction is
   the prefix, the letter is the category, a capital letter is first / last.
2. **`g` does not carry direction.** It is goto and operators (`gr*`, `gd`,
   `gO`, `gc`, `gq`/`gw`). `g[`/`g]` are the exception that proves it: they mean
   left / right *edge*, which is a position, not a direction through a list.
3. **Case means first / last, never direction**, inside the bracket family.
   `n`/`N`, `f`/`F`, `s`/`S`, `gs`/`gS` are native or lightspeed vocabulary and
   are exempt as themselves, not as a pattern to copy.
4. **One category, one door.** `<Tab>`/`<S-Tab>` stay as an accelerator for
   `[b`/`]b`, not as a second vocabulary.

### 6.1 Two duplicate doors removed

`g[`/`g]` (diagnostics) and this config's `[q`/`]q` both restated a Neovim
default on worse terms. `[d`/`]d`/`[D`/`]D` and `[q`/`]q`/`[Q`/`]Q`/`[<C-Q>`/
`]<C-Q>` take a count, and the quickfix ones print a failure as a plain error
message rather than through the Lua error path; neither opens a float on
arrival, which is what this config wants (`virtual_lines` already shows the
text). `ucw.keys.actions.diag_next`/`diag_prev` are gone with them.

### 6.2 mini.ai's goto keys are mini.ai's again

The `g[`/`g]` those two occupied are mini.ai's **upstream default** for
`goto_left`/`goto_right`. This config had blanked them and hand-rolled a
replacement on `[al`/`]al`/`[an`/`]an`/`[il`/`]il`/`[in`/`]in`: 16 global
mappings (`n` and `v`) in which `[`/`]` meant the *edge*, `a`/`i` the textobject
kind, and a third character `l`/`n` the direction — the exact inversion that
made the whole family unreadable next to `[q`. Both halves are put back where
upstream has them, which is also the move Phase 9 (D1) made for lightspeed's
`gS`: restore the plugin's own vocabulary rather than invent a local one.

What is lost: no explicit "previous object" / "next object" selection. mini.ai's
`search_method = 'cover_or_next'` picks the object and a count reaches further
ones. If the trial finds that insufficient, the direction goes *inside* the `g`
namespace on mini.ai's own `n`/`l` letters — never back onto the bracket prefix.

### 6.3 `[h`/`]h` — ipython cells (a key that was never there)

`ucw.keys.actions.iron_send_block({next=true})`, the advance half of
`<S-Enter>`, ran `:normal ]h`. Nothing has mapped `]h` since mini.ai's `goto_*`
keys were blanked, so the advance had been a silent no-op: `<S-Enter>` sent the
cell and stayed put. It calls `M.cell_jump('next')` directly now — the send key
is global, and going through a mapping that exists in one filetype was the bug.

The keys themselves are **buffer-local to python** (`ftplugin/python.lua`):
`# %%` is a Python comment and the textobject that finds it
(`ucw.textobjects.ipython`, mini.ai's `h`/`H`) has nothing to match anywhere
else, so a global pair would be two dead rows in every other buffer's popup.
`h` is the letter the textobject already carries, so this needs no new
vocabulary either.

### 6.4 `[r`/`]r` — references (the other half of snacks.words)

Phase 9 (D2) enabled `snacks.words` for automatic reference highlighting and
deliberately bound no jump key, because the conventional `]]`/`[[` would shadow
the native section motions. Highlighting without navigation is half a feature;
`[r`/`]r` is the same capability in the shape rule 1 asks for, and it shadows
nothing. Declared as `reference_prev`/`reference_next` in `ucw.lsp.actions` (so
`snacks.words.jump` is resolved by name at press time like every other action)
and bound buffer-locally in `ucw.lsp.attach`, for the T6.3 reason: a reference
list exists only where a client is attached. `cycle = true` — the last reference
wraps to the first. A count is not honoured; the action table takes static args.

### 6.5 Guards

`tests/test_keys.lua`: the founding-bug case now asserts `[d`/`]d`/`[D`/`]D`
(that nothing shadows them with an entry of the broken shape), a new case pins
`g[`/`g]` to mini.ai's descs in `n`/`x`/`o`, and a new `cell navigation` set
opens a real `.py` file, walks three cells and then asserts the keys are absent
in a plain buffer. `tests/test_lsp.lua`'s buffer-local census gains `[r`/`]r`.
All three were reverse-verified by breaking the lhs and watching exactly those
three cases fail.

The global keymap snapshot moved by exactly the intended set, 322 → 310
mappings: the 16 `[al`-family entries gone, `[q`/`]q` reading `:cprevious`/
`:cnext` (Neovim's own descs), and `g[`/`g]` reading mini.ai's, now in `o` and
`x` as well as `n`. `[h`/`]h` and `[r`/`]r` are buffer-local and so correctly
invisible to it — which is why they have the instrumented cases above.

## 7. T7 — `<CR>` on a commit, and one key to close a window

Two independent findings from the same session, both about which key does what
in a window this config did not write.

### 7.1 `<CR>` opens codediff, everywhere a commit can be under the cursor

neogit's commit view renders the message well and the diff poorly: one inline
unified hunk list, no file tree, no side-by-side, none of the character-level
highlighting codediff's engine produces. `dd` already reached codediff through
the diff popup (`DiffPopup` → `this` → `integrations/codediff`), so the good
view was two keys away while `<CR>`, the key the hand goes to, opened the poor
one.

`<CR>` is now the same door in both the log view **and** the status buffer, on
commit rows only. Three things make that work, and none of them are obvious
from the code they touch:

- **neogit has no `log_view` mapping table.** The log view binds its own
  functions onto whatever lhs `mappings.status` gave each *action name*
  (`[status_maps["GoToFile"]] = function() … end`), so moving `<cr>` in
  `neogit.setup` would move it in the status buffer too, where it means "open
  the file under the cursor" and has to keep meaning that. The override is
  therefore buffer-local.
- **`FileType` is too early.** `lib/buffer.lua` sets the filetype (:766), then
  the mappings (:785), then shows the window (:807). A `FileType` callback runs
  before neogit's own mapping exists and is overwritten by it — measured, the
  override simply had no effect. `BufWinEnter` is the first event upstream
  guarantees is after the mapping, which is why it is used: an event, not a
  delay standing in for one.
- **"Is there a commit here" is not "is there a yankable here".** The status
  buffer gives *file* rows a `yankable` too — their filename
  (`buffers/status/ui.lua:343`) — so the test has to be the one neogit's own
  `n_goto_file` makes: a row carrying an `absolute_path` is a file, and only a
  row carrying none is a commit. Everything else on the status buffer falls
  through to the callback neogit bound, captured at wrap time. That capture is
  guarded by its own `desc`: `BufWinEnter` fires again every time the buffer is
  shown, and re-reading `maparg` there would capture the wrapper as its own
  fallback.

Reaching codediff through its `commit` section rather than `log`: the `commit`
path resolves through `git rev-parse` and so takes any commit-ish, while the
`log` path only pattern-matches a hex oid out of the string. That is what makes
the same key work on the `Head:` line, on a stash entry, and on a row under
`Recent Commits`.

### 7.2 `<leader>gm` — the commit message, which codediff has nowhere

A codediff tab shows a diff and nothing else: not the subject, not the body,
not even which commit it is. Nor is the message reachable by going back — the
status buffer never had `<S-CR>`, because neogit declares `PeekFile` in the
default mappings and `buffers/status/init.lua` never wires it up. So removing
the commit view from `<CR>` removed the only door to the message.

`<leader>gm` is that door, and it answers from wherever it is pressed: the
commit under the cursor in a neogit buffer, or the revision the current
codediff tab is diffing (`codediff.ui.lifecycle.session`'s per-tabpage
`modified_revision`). `git show --no-patch --format=fuller` into a
`Snacks.win` float — `fuller` because author and committer differ on anything
rebased or cherry-picked, which is exactly what the commit view showed.

The resolver lives in `lua/ucw/git.lua` rather than either plugin spec because
both ends need it: `neogit.lua` rebinds `<CR>` through it, `codediff.lua` binds
`<leader>gm` to it.

### 7.3 `q` closes a window; `<Esc>` does not

Measured across every window this config can open, in a real TUI:

| closes on `q` | lazy, mason, checkhealth, neo-tree, snacks picker, snacks notification history, noice split and popup views, every codediff tab, all four neogit buffers, `man`, the native LSP hover float, gitsigns' preview float |
| --- | --- |
| **also closes on `<Esc>`** | neogit (upstream binds it in the log, commit and popup buffers; the status buffer's is this config's, added so neogit is internally consistent), mason, the snacks picker |
| **`<Esc>` cancels, `q` is a literal character** | the picker's input, `vim.ui.input`, which-key |
| **neither — `:q` was the only way out** | **help, quickfix/loclist** |

So `q` was already the convention, in 11 window kinds out of 13, and `<Esc>`
was a close key in two places only: neogit, and things you type into. The rules
this settles on are a description of that, not a redesign:

1. A window you only read or navigate closes on **`q`**.
2. A window you type into cancels on **`<Esc>`** — native insert-mode
   semantics, where `q` is a character.
3. A terminal (toggleterm, the iron REPL) closes with the key that opened it:
   `q` in normal mode is a macro register and cannot be taken.
4. `<Esc>` keeps its global meaning everywhere else — "clear search highlight
   and dismiss notifications" (`ucw.keys`). Giving it a second, window-shaped
   job would mean pressing it in the many windows where it does not close and
   watching nothing happen.

neogit is a documented exception rather than a thing to fix: upstream binds
`<esc>` in three of its four buffers, and the status buffer's entry in
`neogit.lua` exists so the fourth agrees with them.

The change is one autocmd: `q` → `<C-w>q` in `help` and `qf`, buffer-local,
verbatim from Neovim's own `man` mapping. Everything else already had it.

### 7.4 Guards

`tests/test_git.lua` is new and drives a real `:Neogit` on a throwaway
repository, because both halves of 7.1 read correct and are not: it asserts the
wrap exists and is buffer-local, that a commit row resolves to an oid while a
modified-file row and a section header resolve to nothing, that `<CR>` on the
file row still opens that file, and that `<leader>gm` renders body and
`AuthorDate` for the commit under the cursor and warns where there is no commit.
`tests/test_keys.lua` gains the `q` case, which asserts both halves — mapped in
those two windows, and still unmapped (so still a macro register) in an
ordinary buffer.

One lesson is worth keeping out of the helper's docstring: **neogit paints a
status skeleton before its git calls return** (`Head: 0000000 (no commits)`,
four lines). Waiting on filetype plus a line count caught that skeleton, and
every case then asserted against an empty repository — a green helper and a
meaningless test. The wait is on a `Recent Commits` section existing.

Every case was reverse-verified by reinstating the bug it covers: `FileType`
instead of `BufWinEnter`, the `absolute_path` test removed, the fallback call
removed, `help` without `qf`, and the float's filetype changed — each failed
exactly the cases it should and no others.

The global keymap snapshot moves by exactly one line, 310 → 311: `<leader>gm`.
The `<CR>` override and the `q` mappings are buffer-local and correctly
invisible to it, which is why they have the instrumented cases above.

## 8. T8 — one edit, one notification

Adding a word to the ltex dictionary in a project with a few files open answered
with a stack of identical `Reloaded config` cards — four in a git repo holding
one markdown, one lua, one json and one toml buffer. Neither the count nor the
subject was ltex's.

**Where the copies came from.** `ucw.lsp.vscode` built its watchers in
`M.attach`, i.e. **per client**: every client rooted in the project got its own
`FileWatcher` on the root and its own on `.vscode`, all four pairs on the same
two paths. A dictionary write is one directory change, so each pair found it
separately, each called `M.reload` for its own client, and each announced its
own success — with a message whose only variable part was the directory, and
whose client name lived in the notification *title*. ltex itself is silent
throughout: `ltex_dict`'s command handler calls `vscode.reload(client)`
synchronously after writing the file, so by the time any watcher fires that
client is already up to date and the push-when-changed guard returns false.

**What it is now.** Watchers are keyed by settings directory (`watched[dir]`),
with the set of client ids that read it. A client attaching to a directory that
is already watched joins the group instead of starting a second pair. `refresh`
reloads every member — they still compose over different bases, so the reload
stays per client — collects the ones that actually changed, and sends **one**
notification naming them: `Reloaded config: <dir>` + `basedpyright, jsonls,
lua_ls, marksman, ruff, taplo`. The title is plain `LSP` now, because the
subject of the event is the directory. Clients whose settings did not change
stay out of the message entirely.

`M.detach` drops a client from every group and closes a group's watchers when
its last client leaves, which is what `is_watching` (unchanged in meaning: "has
running watchers") keeps observable.

**Deliberately not changed.** The sidecar keys are all `ltex.*`, and
`read_sidecars` merges them into *every* client of the directory, so `taplo` and
`lua_ls` carry an `ltex.dictionary` they will never read. Gating the merge on
"does this server declare an `ltex` section" would rest on nvim-lspconfig
happening to ship `ltex.enabled` as a default — a silent breakage of the
dictionary the day it stops. The junk is one key in a settings table that is
pushed anyway; VSCode's own convention puts every server's settings in one
`settings.json` too.

### 8.1 The same finding in the other renderer

Chasing the count turned up its twin: LSP progress was being drawn twice.
lualine owns that display (`lua/ucw/plugins/lsp_progress.lua`, lsp-progress.nvim,
loaded on `LspAttach`), while noice renders `$/progress` by default and nothing
turned it off — so each server report was a statusline spinner *and* a
notification card. basedpyright emits a begin/report/end triple per analysis
pass, which is why opening a Python buffer stacked several `basedpyright` cards
over the buffer text: measured 27 `LspProgress` events in the six seconds after
one `:edit`. `noice.lua` now sets `lsp.progress.enabled = false`; the lualine
spinner is untouched (measured: 8 `LspProgressStatusUpdated` events on the next
`:edit`, and no cards).

### 8.2 Guards

`tests/test_lsp.lua` gains *one directory change is one notification*: two fake
clients on one root, an edit to `.vscode/settings.json`, then a wait for both to
carry the new value plus a full debounce window for the group's second watcher
to prove it adds nothing. It asserts exactly one `Reloaded config:` notice and
that the message names both servers. Reverse-verified: with the per-client
watchers reinstated it reports 2.

## 9. T9 — one notch coarser on the same jumplist

`<C-o>`/`<C-i>` step one *entry*, and a handful of edits in one file put a dozen
entries there, so "back to the file I came from" is the native key held down
until the name in the statusline changes. `<C-S-o>`/`<C-S-i>` do that in one
press, and take a count in files (`3<C-S-o>`). The mouse side buttons get the
same pair with Shift, matching the plain ones already bound next to them.

**Why this is not `[f`/`]f`.** T6 rule 1 says previous/next is `[`/`]` plus a
category letter and nothing else, and this is deliberately outside it. The
jumplist's door has never been in that family: it is `<C-o>`/`<C-i>`, which rule
3 lists among the native vocabularies that are exempt as themselves. What is
being added is not a new category — it is a coarser step through *the same
list*, so it belongs on the same keys with a modifier. Spelling it `[f`/`]f`
would give one list two vocabularies, which is the thing rule 4 exists to
prevent.

**The jump is Neovim's.** `ucw.keys.actions.jump_file` works out how many
presses reach the landing entry and runs `{steps}<C-o>`; it never moves the
cursor itself. Anything that did (`nvim_win_set_cursor`, `:buffer`) would leave
the jumplist describing a history that never happened, and the next native
`<C-i>` would go somewhere the user never was. Running out of entries in that
direction is a no-op with a notification, the same shape Neovim's own `[q`/`]q`
have at the end of a list.

### 9.1 Terminal prerequisite

The same one `<C-i>` itself has (Phase 9, D6): Ctrl and Ctrl+Shift are one byte
to a terminal unless it speaks CSI-u. tmux is already configured for it; Konsole
gets there through the user's keytab, and that keytab needs an entry per key —
**an unlisted modifier in a keytab rule means "don't care"**, so the existing
`key I+Ctrl` was matching Ctrl+Shift+I as well and emitting the Ctrl+I sequence
for both. Split, plus the missing half for O:

```
key I+Ctrl-Shift : "\E[105;5u"
key I+Ctrl+Shift : "\E[105;6u"
key O+Ctrl+Shift : "\E[111;6u"
```

Measured against a real TUI by injecting the bytes and reading back which
mapping fired, because how Neovim folds Shift into a control character is not
something to assume: `\E[105;5u` → `<C-I>`, `\E[105;6u` → `<C-S-I>`,
`\E[111;6u` → `<C-S-O>`, `0x0f` → `<C-O>`, `0x09` → `<Tab>`, all distinct. The
shifted codepoint (`\E[73;6u`) arrives as `<C-S-I>` too, so either spelling
works; the unshifted one matches the entry that was already there.

Nothing here breaks without the keytab. The keys simply arrive as `<C-o>`/`<C-i>`
and do the fine-grained jump, which is what they did before.

### 9.2 `win_backward_buf` answered nothing

`ucw.utils.win_backward_buf` — "find backward in jumplist until the buf is
different" — already computed this, and had never once returned an answer.
`getjumplist()` returns `{list, idx}` together; the function took the list out
of the pair and then indexed *that* as if it were still the pair, so what it
called the jumplist was a single jump entry, `#jumplist` was 0, and it bailed
out for every window that had one. Nothing showed: `bufdelete`'s next-buffer
choice falls through to the alternate buffer and then to the buffer list, both
of which look like a deliberate policy from the outside.

It is one function with the direction and the file count as parameters now, and
`win_backward_buf` is the backward-by-one wrapper over it, so the buffer
`bufdelete` lands on and the entry `<C-S-o>` lands on are the same rule rather
than two implementations of it.

### 9.3 Guards

New test file `tests/test_utils.lua`: the landing rule directly, asserting the
step count next to the buffer (a right buffer reached by the wrong number of
presses lands somewhere else), and `bufdelete` going through it with a decoy
buffer in the list that the fallback would have reached first.

New `file-granular jumplist` set in `tests/test_keys.lua`: three real files, and
the assertion is the *contrast* — from one position `<C-o>` stays in the file
while `<C-S-o>` leaves it — because a `<C-S-o>` that simply forwarded to `<C-o>`
would pass a landing-place assertion whenever the two happen to agree. Plus the
count, the far end being a no-op, and all four lhs being global and labelled.

One trap that cost a run: **`<C-i>` cannot be driven through `type_keys` here.**
It is byte 0x09 and so is `<Tab>`, which this config cycles buffers with — over
RPC there is no terminal in the way to tell them apart, so `nvim_input('<C-i>')`
lands in another buffer entirely. The native half of the contrast goes through
`:normal!`, with a `1` count because `:normal!` eats the whitespace between
itself and an argument that *is* a tab.

The global keymap snapshot moved by exactly the intended set, 311 → 315: the two
Ctrl+Shift keys and the two Shift+mouse ones, all four labelled.

## 10. T10 — three things that were red and one that was noisy

Not keybindings. Grouped because each is a gate or a daily annoyance that had
been failing long enough to read as background.

### 10.1 The lint gate was checking a plugin that is not installed

`scripts/luarc-lint-config.lua` globbed `<lazy-root>/*/lua`. That is every
plugin directory **on disk**, which is not the plugin set: lazy deletes a
plugin dropped from the spec only on `:Lazy clean`, which nothing here runs.
`diffview-plus.nvim`, swapped out for codediff in `6f341e6`, was still there
and still in the library.

A library entry is not inert. lua_ls types a `vim.opt` field from every
assignment it can reach, and diffview assigns a list to `vim.opt.diffopt`
(`vim.opt.diffopt = vim.deepcopy(orig_diffopt)`), which makes the field a list
everywhere and `:append` an undefined field — in *this* repo's `options.lua`,
on two lines untouched since 2022. Diffview carries a
`---@diagnostic disable-next-line: undefined-field` over its own
`vim.opt.eventignore:prepend` for the same reason, with the comment
"`vim.opt.X` is magic; LuaLS doesn't see it as `vim.Option`".

§12's earlier entry called the warnings bogus and the cause unisolated. Half
right: the warnings are false, and the cause is exactly one directory. The
isolation attempt that failed had checked a single file rather than the repo,
where the workspace is different enough to hide it.

The library is named from `lazy-lock.json` now, which is also the set CI
installs, so the two gates see one library. `options.lua` additionally takes
`diffopt` through a `---@type vim.Option` local: the annotation states what
`vim.opt.X` always is, and with the poisoned directory forced back into the
library the diagnostic is gone — so a future plugin doing the same cannot
reopen this.

### 10.2 CI was red on a pin outside the lockfile's reach

`test (stable)`'s "lazy-lock.json did not drift" step, on every push since the
gate existed. The drift was one line, always the same one: `lazy.nvim`'s own.

lazy.nvim manages itself like any other plugin and records its commit in the
lockfile, but it is the one plugin it cannot *install* — the config clones it
before lazy exists. `bootstrap_lazy()` cloned `--branch=stable`, so every
fresh install got whatever `stable` pointed at that day and lazy wrote that
commit into the lockfile. A moving pin, in the one place the lockfile could
not cover, failing the gate whose whole job is to notice moving pins.

It clones the default branch and checks out the locked commit now (reachable:
`stable` is cut from `main`), falling back to `stable` when there is no
lockfile entry at all. Reproduced both ways against a scratch `XDG_DATA_HOME`
with every plugin installed from nothing: the old spelling reproduces the exact
CI diff, the new one leaves the lockfile untouched.

### 10.3 `K` in a python buffer always said it found nothing

`vim.lsp.buf.hover()` asks every hover-capable client and notifies "No
information available" once per empty answer. ruff advertises the capability
and then answers with nothing at nearly every position — it documents `noqa`
codes and little else — so every `K` drew basedpyright's float and, beside it,
a report that the hover had found nothing.

The capability is taken away at attach, from a table keyed by client name in
`ucw.lsp.attach`, rather than declined in `after/lsp/ruff.lua`: the initialize
response is where it is decided, and `after/lsp/` files here are table-only by
rule. Ruff's own editor documentation says to decline it wherever a type
checker is attached. A genuine "nothing here" still reports, once.

### 10.4 Guards

`tests/test_lsp.lua` gains the ruff case, on a fake client *named* ruff —
what decides this is the name in the attach handler, not anything the binary
does — with the basedpyright half next to it, because taking the capability
from every client would be the same bug with the sign flipped.

The other two are gates rather than behaviour, and their guard is the gate:
`just lint` is clean, and the drift check was reverse-verified by restoring
the old bootstrap and watching the same one-line diff come back.

## 11. T11 — neo-tree off `v2.x`

T10's open item, closed rather than carried: `v2.x` registers `BufModifiedSet`
unconditionally, Neovim has removed that event, and the branch is two majors
behind with no fix coming. `v3.x` chooses between `BufModifiedSet` and
`OptionSet modified` at runtime, so `tests/test_neotree.lua` — the case that
found this — now passes on both Neovims instead of being a standing red on the
nightly leg.

The migration itself is three lines. `vim.g.neo_tree_remove_legacy_commands`
and the `init` hook that set it are gone: 3.0 removed the legacy `NeoTree*`
commands outright, and this config had been on `:Neotree` since Phase 1.
`follow_current_file` is a table (`{ enabled = true }`). Nothing else in the
config touched a removed API — no `NeoTree*` command, no `utils.table_copy` /
`table_merge`.

### 11.1 What the lint gate caught that opening the tree did not

Four diagnostics, all upstream annotations narrower than upstream's own code,
and all four are `---@diagnostic disable-next-line` with the evidence named
(the §7 rule in phase7-ci.md):

- `toggle_directory`'s `path_to_reveal` is annotated `string`. nil means
  "reveal nothing": the value is forwarded to `fs_scan.get_items`, whose own
  wrappers annotate it `string?` and whose reveal step is
  `if path_to_reveal then`, and upstream's own caller passes nothing after the
  node. Three call sites here, two of them as `missing-parameter`.
- `window.width` is annotated `integer?`, and the renderer still resolves it
  through `utils.resolve_config_option`, which calls a function value with
  `state`. Measured rather than argued: opened in a directory whose `:~` root
  name is longer than the default, the tree comes up at the computed width and
  not at 40.

### 11.2 `zR` expanded one level per press

Loading a directory is asynchronous. `toggle_directory` returns with the node
still `loaded == false` and no children in the tree — measured directly: right
after the call `#tree:get_nodes(id)` is 0, and two seconds later it is 6. So
`recursive_open`, which opens a node and immediately asks for its children,
saw none and stopped one level short of wherever the loading had got to.

The visible shape of that: `zR` on a cold tree went 16 → 55 → 98 → 152 → 154
lines across four presses instead of expanding everything once. Every
depth-limited key had the same ceiling; they get away with it because they ask
for one more level at a time, and that level is usually loaded already.

`zO`/`zR` go through `node_expander.expand_directory_recursively` with the
filesystem source's `prefetcher` now — upstream's answer to exactly this, which
collects the unloaded nodes, prefetches them and expands again. It runs inside
a coroutine, so the depthlevel is recorded in the completion callback rather
than after the call returns: a callback, not a wait. `zR` is one press and
idempotent, and the depthlevel it records is the tree's real depth, so `zm`
after `zR` steps down from the bottom instead of from a number `zR` had
guessed before the expansion happened.

`recursive_open` stays for the depth-limited keys.

### 11.3 A nil that is guarded but not reproduced in a test

The same drive turned up `attempt to index local 'node' (a nil value)` out of
`zm`/`zx`, and it is not a migration break — **the identical error reproduces
on `v2.x`**, which is how that was ruled out. (Worth stating because the first
`v2.x` A/B was invalid: `Lazy! install` does not downgrade an installed plugin,
so it measured v3 twice.)

`redraw_after_depthlevel_change` indexed `get_node()` unconditionally, and that
resolves the *cursor's line* against a tree `set_depthlevel` has already
collapsed while the buffer still shows the longer rendering. It returns early
now, and the parent walk stops at the root.

**The stated cause was wrong once and is worth correcting in place**, because
the wrong one is more plausible than the right one: it is *not* that
`(N hidden items)` is a line without a node. Measured — every line in a
rendered tree, that one included, resolves to a node.

What this does not have is a guard, and that is deliberate rather than
overlooked. The condition needs the tree in a state that took eight fold
keypresses to build, and a child driven through those keypresses reproduces it
**sometimes** — the intermediate expansions are asynchronous, so the state at
key nine is not the same twice. A guard that passes and fails on its own
schedule is worse than none: it is indistinguishable from the working gate it
is pretending to be, which is the failure mode this repo keeps writing down.
So the guard covers the two `zR`/`zm` claims of §11.2, both reverse-verified by
restoring the old `zR`, and the nil check stands on its own argument — nui
annotates `get_node()` as returning `NuiTree.Node?`, and a parent lookup at the
root returns nothing.

## 12. What this changes in earlier documents

| document | passage | now |
|---|---|---|
| `phase9-keybindings.md` | §2.5 D5, §3 layout | `<leader>e`/`E` gone (T1); group labels renamed (T2) |
| `phase9-keybindings.md` | §5 extension rule | a new namespace also needs a lowercase label, an explicit icon, and `mode = { 'n', 'x' }` (T2) |
| `phase4-folding-comments.md` | §3.2 diagnostic default | `virtual_lines` defaults to `false` (T4) |
| `phase9-keybindings.md` | §2.2 r2.1 (no jump key for snacks.words) | jumps are `[r`/`]r`, buffer-local (T6) |
| `phase9-keybindings.md` | §5 extension rule | previous/next is `[`/`]` + a category letter, and nothing else (T6); a read-only window closes on `q` (T7) |
| `phase3-settings-composition.md` | §5 "the only per-client state left is the base snapshot and the watchers" | watchers are per settings directory, shared by the clients that read it (T8) |
| `phase9.5-trial-period.md` | §6 rule 1 (previous/next is `[`/`]` + a letter, and nothing else) | a coarser step through a list a native vocabulary already owns stays on that vocabulary's keys (T9) |
| `phase9.5-trial-period.md` | §12 "`just lint` fails locally … which library entry is responsible was not isolated" | it is `diffview-plus.nvim`, left on disk by the codediff swap; the library is named from the lockfile now (T10.1) |
| `phase7-ci.md` | §1.5a the lint library is every plugin directory on disk | it is every *locked* plugin; a leftover is not a plugin (T10.1) |
| `phase7-ci.md` | §9.8 "moving off `v2.x` is a plugin decision, not a CI fix" | the decision was made: neo-tree is on `v3.x` (T11) |

Phase 8's documents are not amended: they record the Phase 8 tree, which Phase 9
already superseded.

## 13. As-built

`9252521` T4 → `ab3c8e6` T1 → `3716ee1` T2 → `044920f` T5 → `7430074` T3 →
`c492113` T5 fixes (self-review) → `a88ac1a` label nit → `0f74c1f` T6 →
`97b9b71` T7.1/7.2 → `ba3d4ed` T7.3 → `7bc16a5` T8 → `3af3df7` T8.1 →
`3d733b0` T9.2 → `9ad7de4` T9 → `8e3804d`/`62f9a85` T10.1 → `18d14f3` T10.3 →
`630e79f`/`2d15b98` T10.2. Outside this repo: yadm `9098ba4` (tmux
`focus-events`) and the Konsole keytab entries T9.1 lists.

Every behaviour change carries a guard, and every guard was reverse-verified by
reinstating the bug it covers — including one that was not deliberate: a
truncated write during a btrfs `ENOSPC` silently dropped the `desc` from
`map('v', '<c-s>', …)`, and the new guard caught it as `x <C-S>` on the next
run.

`tests/test_lsp.lua` gains the T8 case (one directory change is one
notification).

`tests/test_utils.lua` is new (T9): the jumplist landing rule, and `bufdelete`
going through it.

New test file: `tests/test_autoread.lua` (reload happens; modified buffer is
left alone; the notice speaks on reload and stays quiet on delete; neither
autocmd group exists under firenvim, and both exist in the full UI). New cases
in `tests/test_keys.lua`: the first-level census (icon present, group lowercase,
leaf Sentence-case), the visual-mode header census, "gq/gw map nothing", the
unlabelled-key scan over `n`/`x`/`o`, mini.ai's ownership of `g[`/`g]`, and the
`cell navigation` set, and the `close with q` set. `tests/test_git.lua` is new
(T7): a real `:Neogit` on a throwaway repository, both halves of the `<CR>`
divert and both halves of `<leader>gm`. The `file-granular jumplist` set in
`tests/test_keys.lua` is T9's.

## 14. Open

- **`<leader>e`/`E` are free.** So are `a d h i j k m o p v x y z` and most
  capitals (§3 of Phase 9); `d` and `a` stay reserved for the debugger and AI
  goals.
- **rustaceanvim's buffer-local `<leader>a`** is still squatting the reserved AI
  letter (carried over from Phase 9 §7).
