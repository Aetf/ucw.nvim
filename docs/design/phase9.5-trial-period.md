# Phase 9.5 — trial-period tuning

Status: **as-built record, written as the changes landed (2026-08-22/23).**

Phase 9 (`phase9-keybindings.md` r3) ended with "real-session trial runs next".
This is that trial: the config in daily use, each thing that turned out wrong
fixed in its own commit with its own guard. It is a *design* document rather
than a changelog because three of the five changes rest on mechanisms that are
not obvious from the code they touch, and the next person to add a `<leader>`
key or an autocmd needs them.

**Where this supersedes an earlier phase document, that document now says so
inline and points here.** Phase 10 (the as-built rewrite of `AGENTS.md` and
`docs/architecture.md`) is what folds all of this into one current description;
until then, a phase document is the record of its own phase, and this one is
the record of what the trial changed afterwards.

Nothing here reopens a Phase 9 decision. D1–D10 all stand; what the trial found
was one duplicate door, a presentation layer nobody had looked at as a whole,
and two editor behaviours that were quietly broken.

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

## 6. What this changes in earlier documents

| document | passage | now |
|---|---|---|
| `phase9-keybindings.md` | §2.5 D5, §3 layout | `<leader>e`/`E` gone (T1); group labels renamed (T2) |
| `phase9-keybindings.md` | §5 extension rule | a new namespace also needs a lowercase label, an explicit icon, and `mode = { 'n', 'x' }` (T2) |
| `phase4-folding-comments.md` | §3.2 diagnostic default | `virtual_lines` defaults to `false` (T4) |

Phase 8's documents are not amended: they record the Phase 8 tree, which Phase 9
already superseded.

## 7. As-built

`9252521` T4 → `ab3c8e6` T1 → `3716ee1` T2 → `044920f` T5 → `7430074` T3 →
`c492113` T5 fixes (self-review) → `a88ac1a` label nit. Outside this repo:
yadm `9098ba4` (tmux `focus-events`).

Every behaviour change carries a guard, and every guard was reverse-verified by
reinstating the bug it covers — including one that was not deliberate: a
truncated write during a btrfs `ENOSPC` silently dropped the `desc` from
`map('v', '<c-s>', …)`, and the new guard caught it as `x <C-S>` on the next
run.

New test file: `tests/test_autoread.lua` (reload happens; modified buffer is
left alone; the notice speaks on reload and stays quiet on delete; neither
autocmd group exists under firenvim, and both exist in the full UI). New cases
in `tests/test_keys.lua`: the first-level census (icon present, group lowercase,
leaf Sentence-case), the visual-mode header census, "gq/gw map nothing", and the
unlabelled-key scan over `n`/`x`/`o`.

## 8. Open

- **`<leader>e`/`E` are free.** So are `a d h i j k m o p v x y z` and most
  capitals (§3 of Phase 9); `d` and `a` stay reserved for the debugger and AI
  goals.
- **`just lint` fails locally, and did before any of this.** Two bogus
  `undefined-field: append` warnings on `vim.opt.diffopt` (`options.lua:99/101`,
  lines untouched since 2022). What is measured: it is the *library set*, not
  the source. The generator (`scripts/luarc-lint-config.lua`) globs
  `<lazy-root>/*/lua` — every plugin directory **on disk** — and this machine's
  root holds two that a fresh one does not (`firenvim`, plus `diffview-plus.nvim`
  left over from the codediff swap `6f341e6`). Checking a *clean* tree with this
  machine's generated config reproduces the warnings; checking this tree at the
  pre-trial commit reproduces them too; a worktree, which gets its own data root
  from `NVIM_APPNAME`, is clean, and so is CI. Which library entry is
  responsible was not isolated — removing `diffview-plus.nvim` alone changes the
  finding set in a way that suggests lua_ls resolution order, not one bad
  directory.
- **rustaceanvim's buffer-local `<leader>a`** is still squatting the reserved AI
  letter (carried over from Phase 9 §7).
