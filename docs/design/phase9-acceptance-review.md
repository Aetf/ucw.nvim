# Phase 9 + 9.5 acceptance review (2026-09-14)

Independent audit of `c7abf52^..19bfd81` (55 commits: the Phase 9 design doc,
the 13 D1–D10 implementation commits, the r3 as-built doc, and the Phase 9.5
trial-period commits T1–T11 with their docs), against
`docs/design/phase9-keybindings.md` r4 and `docs/design/phase9.5-trial-period.md`.
Everything below was measured on this machine — one real TUI boot driven over a
`--listen` socket from a tmux session started in `/tmp` (Neovim 0.12.5, plugins
at `lazy-lock.json`: which-key `3aab214`, snacks `882c996`, neogit `37e0f22`,
codediff `e08a35a`, neo-tree `v3.x` `ebd6676`), the suite run twice, and
thirteen deliberate breakages of the guards this range added, each run in a
scratch worktree at `19bfd81` and reverted.

## Verdict

The layout is what the two documents say it is, and the trial period's guards
are real: eleven of the thirteen breakages went red on exactly the case that
claims to cover them. **Two defects and four findings**, ranked below. The two
defects are in keys this range touched without re-reading: the mouse side
buttons in insert mode (R1) and the REPL block-send keys on a machine without
the REPL binary (R2). The rest is the sentence every review in this project has
ended on — **each self-built instrument stops exactly where the phase's
attention stopped**: the first-level popup census reads which-key's registry
and cannot see a first-level key registered the way §5 tells the next plugin
to register one (R3); two as-built claims that were "verified live" have no
guard (R4); and the range left behind a set of stale statements, several of
them in text `AGENTS.md` certifies as current (R5).

## What was re-verified and holds

* **Suite**: `just ci` twice on the tree as committed — **183/183, exit 0**
  both runs. `just lint` green ("Diagnosis completed, no problems found";
  library "44 library entries (42 of 47 locked plugins)" with **48**
  directories under `lazy/` — `diffview-plus.nvim` is on disk and excluded, so
  T10.1's lockfile-named library does what it says). `just fmt-check` green.
* **The global mapping set is exactly the documented one.** Independent
  snapshot from the TUI (`scripts/keymap-snapshot.lua`, fresh boot, cwd
  `/tmp`, no interactive input before the dump, which-key loaded and VeryLazy
  drained): **315 mappings**, which is the documents' arithmetic
  (324 r3 → 322 T1 → 310 T6 → 311 T7 → 315 T9). The `<leader>` first level is
  `b c f g l n q r s t u w ? \``; no `<leader>e`/`E`, no `<leader>T`, no
  `<leader>gt*`, no old `<leader>l*` tree, no `<leader>n[dhn]`, no
  `<leader>s[crs]` session keys, no `wh`. `grr`/`gri`/`grt`/`gO` carry the
  picker descs, `grn`/`gra`/`grx` are native and untouched, `gS` is
  `<Plug>Lightspeed_gS`, `gE` is unmapped. `g[`/`g]` read mini.ai's
  `Move to left/right "around"` in `n`/`x`/`o`; the 16 `[al`-family entries
  are gone; `[q`/`]q`/`[d`/`]d` are Neovim's own (`silent=0`, no desc of the
  broken shape); `[c`/`]c` are gitsigns' `expr` pair. `<C-S-O>`/`<C-S-I>`/
  `<S-X1Mouse>`/`<S-X2Mouse>` are present, normal-mode only, labelled.
  `<leader>gm` is present as a lazy stub. Every `<leader>` key this config
  owns is `silent=1`; the only `silent=0` leader keys are the lazy-load stubs
  (`gg`, `gh`, `gm`, `go*`), which are `expr=1 replace_keycodes=1` by
  construction.
* **`<C-p>` is `smart` with `multi = { "recent", "files" }`** — read off the
  live picker (`Snacks.picker.get()[1].opts`), so buffers keep their one door.
* **All seven `<leader>u` toggles flip both ways, driven by the real keys.**
  State read back after each press: `uh` inlay hints `true→false→true`
  (global *and* buffer flag together), `uv` `false→{current_line=true}→false`
  and **back on from visual mode** (`V` then `<leader>uv`), `uD`
  `vim.diagnostic.is_enabled()` `true→false→true`, `uw`/`us` window options,
  `ub`/`ud` gitsigns config. **Inlay hints are global**: after `<leader>uh` in
  `a.py`, opening `b.lua` (lua_ls attaches) reads `is_enabled({bufnr=0}) =
  false`, and the next press turns both back on.
* **The buffer-local LSP set is the D1+T6 set and works.** On a lua_ls
  buffer, `nvim_buf_get_keymap` shows exactly `gd`, `gD`, `<M-CR>` (n and x),
  `<C-K>`, `[r`, `]r` plus which-key's triggers; `]r` moved the cursor from
  `M` at (2,10) to the next reference (3,7) and `[r` back to (2,9). None of
  `gr ge g0 gt gH gW <M-S-r>` are buffer-local. `<leader>?` renders those six
  with their descs.
* **`[h`/`]h` are buffer-local to python, in `n` and `x`**, and walk cells
  2→3→5→3 on a three-cell file.
* **`q` closes help and quickfix** (`maparg('q').buffer == 1` there, one
  window left after the press) **and is unmapped in an ordinary buffer**
  (`maparg('q','n') == ''`). Every codediff tab, the neogit log view and
  status buffer, and the `<leader>gm` float also closed on `q` during the
  drive below.
* **T7, both halves, in the real neogit.** Status buffer: `<CR>` carries
  `Diff this commit (codediff)` and `buffer == 1`; on a `Recent Commits` row
  `commit_under_cursor()` returns the full oid; `<CR>` there opens a codediff
  tab whose `codediff.ui.lifecycle` session reads
  `modified_revision = <oid>`, `original_revision = <oid>^` (polled, then
  `redraw!`; screen shows the side-by-side `a.py` diff). Log view (`:Neogit
  log` → `l`): the wrap is present and buffer-local, `commit_under_cursor()`
  resolves the oid from the ` * second commit` graph row, and `<CR>` opens the
  same codediff session. `<leader>gm` on the status row renders a `git`-ft
  float (`relative = "editor"`) with the subject and `AuthorDate`; inside the
  codediff tab it renders the message for that tab's revision.
* **T8: one directory change is one notification**, with real servers. With
  `basedpyright`, `ruff` and `lua_ls` attached to one repo (all three
  `is_watching == true`), writing `.vscode/settings.json` produced exactly one
  new history entry: title `LSP`, `Reloaded config: <dir>/.vscode /
  basedpyright, lua_ls, ruff`.
* **T5: a file rewritten outside nvim reloads on idle** — one keypress, then
  `line 1` became `REWRITTEN` and the history's last entry is
  `Reloaded from disk (changed externally)`.
* **T9 stepping**: from `f3:7` with the jumplist `f1:1 f1:5 f1:15 | f2:1
  f2:4 f2:12 | f3:1`, native `1<C-o>`/`1<C-i>` stay in `f3`; `2<C-S-o>` lands
  on `f1:15`; `<C-S-i>` → `f2:1` → `f3:1`; a third press is a no-op with the
  `No later file in the jumplist` notice.
* **T2 renders.** The normal-mode `<leader>` popup shows every first-level
  row with an explicit icon and lowercase group names (`+buffer`, `+code`,
  `+find`, `+git`, `+quit/session`, `+repl`, `+search`, `+tab`, `+toggle/ui`,
  `+window`); the visual-mode popup shows `+code +git +repl +search
  +toggle/ui` by name, not `+N keymaps`.
* **The guards bite.** Each breakage below was applied to a scratch worktree,
  the guarding file run alone, and the tree restored; each failed *only* the
  named case(s):
  | breakage | red case |
  |---|---|
  | `<leader>r` header loses its `icon` | first-level label/icon census |
  | `<leader>c` header loses `mode = {n,x}` | visual-mode header census |
  | `v <c-s>` loses its `desc` | unlabelled-key scan |
  | `q` only in `help`, not `qf` | close with q |
  | `jump_file` forwards `1<C-o>` | Shift-steps-a-file contrast |
  | `[h`/`]h` made global | cell navigation |
  | `[r`/`]r` dropped from attach | buffer-local D1 set |
  | ruff's `hoverProvider` no longer declined | ruff's hover is declined |
  | watch groups keyed per client again | one directory change is one notification |
  | neogit hook on `FileType` instead of `BufWinEnter` | is wrapped once neogit has bound its own |
  | `virtual_lines` default back to `{current_line=true}` | off by default + toggles on and back off |

## R1 (defect) — the mouse side buttons are broken in insert mode, and this range labelled them as working there

`ucw.keys` binds `<X2Mouse>` → `<c-i>` and `<X1Mouse>` → `<c-o>` with
`noremap` in `{ 'n', 'i', 'v' }`. In insert mode those right-hand sides are
Neovim's own `i_CTRL-I` (insert a tab) and `i_CTRL-O` (execute one normal-mode
command), not the jumplist.

Measured with real mouse events (`nvim_input_mouse`) in the live TUI, on a
buffer holding `abc`: x2 in insert mode left the mode `i` and the line `abc `
(a tab, expanded); x1 in insert mode put the editor in `niI` (one-shot normal
pending) and the next key, `$`, ran as a normal command — line unchanged,
cursor at the end.

The pair predates the range (initial commit), but two commits in it touched
exactly these lines and neither re-read them: T3 (`7430074`) added
`desc = 'Jump forward (jumplist)'` / `'Jump back (jumplist)'` to all three
modes — so the insert-mode popup now labels a key that inserts a tab as a
jump — and T9 (`9ad7de4`) bound the Shift pair *normal-mode only* with a
comment saying why ("`<C-o>` there is Neovim's own one-shot normal command"),
i.e. it identified the bug and left it standing one line above. Same class as
Phase 8 R5's `[c`: the defect sits in the lines the phase was editing.

**Suggested fix.** Either drop `i` from the mode list (matching the Shift pair
and the reasoning already written next to it), or give insert mode its own
rhs (`<C-o><C-o>` / `<C-o><C-i>`) so the buttons do in insert mode what the
label says. Reverse-verify with `nvim_input_mouse` as above; the desc scan will
not catch either state.

## R2 (defect) — without the REPL binary, `<C-CR>`/`<S-CR>` warn once and then type an `h` into the buffer

`4a50fec` ("REPL keys degrade to a one-time warning without the binary") wraps
every `<leader>r*` rhs in `repl_key`, and its test drives `<leader>rr`. The two
block-send keys are not wrapped: `ucw.keys.actions.iron_send_block` runs
`nvim_feedkeys('<leader>rsih', 'mx')`. When the wrapper on `<leader>rs`
declines (no binary), it returns without starting an operator, so the remaining
`ih` is executed as normal-mode input — `i` enters insert mode and `h` is
inserted at the cursor.

Measured in the live TUI (`ipython` not on PATH here, `executable() == 0`):
`<C-CR>` on `a = 1` produced the once-per-filetype warning **and** turned the
line into `ha = 1` with the buffer modified; `<S-CR>` on the second press
produced no warning (as designed) and still went through the same path, then
moved the cursor to the next cell. So on the machine that motivated the fix,
the two keys that send blocks — the ones a REPL user presses most — corrupt the
buffer instead of degrading.

**Suggested fix.** Put the probe in front of the feedkeys — export `repl_ready`
from `iron.lua` (or move it next to `iron_send_block`) and return early — or
better, stop going through typeahead at all: resolve the `ih` textobject range
with `mini.ai` and hand it to `iron.core.send` directly, which also removes the
`'mx'` re-entrancy. Add the case next to the two `REPL keys` cases, driven
through the real `<C-CR>` mapping, asserting the buffer is unchanged.

## R3 (method, test coverage) — the first-level popup census reads which-key's registry, so it cannot see a first-level key registered the way §5 says to register one

T2's rule 3 is "every first-level entry names its own icon", and the guard is
`tests/test_keys.lua`'s *every `<leader>` first-level entry follows the
label/icon rules*, which iterates `require('which-key.config').mappings` — the
`wk.add` registry. Its own comment says so: "Only `wk.add` entries are visible
in `Config.mappings` - a lazy `keys =` entry never lands there". `keys =` in
the plugin's own spec is exactly what §5 (P5) tells the next plugin to use.

Measured: adding `{ '<leader>e', '<cmd>Neotree toggle<cr>', desc = 'Explorer' }`
to `snacks.lua`'s `keys =` in the scratch worktree leaves `test_keys.lua`
**21/21 green**. The same mapping installed in the live TUI renders in the
popup as `e ➜   Explorer` — a blank icon column next to `l ➜ 󰒲` — the exact
presentation defect T2 fixed by hand. The census also pins the first level as
an exact list, so it doubles as T1's only guard that `<leader>e`/`E` stay gone,
and it is blind there too.

This is Phase 8 R2's finding with the mechanism swapped: a guard that reads
one registration mechanism's registry certifies a rule over keys that use
another. The unlabelled-key scan two cases down already does it right
(`nvim_get_keymap` over `n`/`x`/`o`, then which-key labels as a union).

**Suggested fix.** Build the first-level set from `nvim_get_keymap('n')` (lhs
= `<leader>` + one character, `<Plug>` excluded) and join it with
`Config.mappings` for icon/label/group; a first-level lhs present in the
mapping table with no `Config.mappings` icon entry fails the census. Reverse-
verify with the `keys =` plant above, measured green today.

## R4 (test coverage) — two as-built claims verified live, guarded by nothing

* **`<C-p>`'s one-door guard.** §2.3 r2.1 named the risk (snacks' `smart`
  defaults to `multi = { buffers, recent, files }`, giving buffers a second
  door), §7 says it is "verified live (`p.opts.multi`)". Measured: removing
  `{ multi = { 'recent', 'files' } }` from `snacks.lua` leaves
  `tests/test_picker.lua` **12/12** and `tests/test_keys.lua` **21/21** green.
  The only guard is the design doc.
* **The log-view half of T7.** `tests/test_git.lua` drives `:Neogit` and
  asserts the wrap, the divert and the fallback on the **status buffer** only.
  §7.1's claim is "`<CR>` is now the same door in both the log view **and** the
  status buffer", and the log view is the more likely to move — it has no
  mapping table of its own and takes its lhs from `mappings.status` by action
  name, which is the mechanism §7.1 itself documents as fragile. It works today
  (measured above); nothing would notice if it stopped.

**Suggested fix.** One `test_picker.lua` case that opens `<C-p>`'s picker and
asserts `Snacks.picker.get()[1].opts.multi == { 'recent', 'files' }`; one
`test_git.lua` case that opens the log view (`require('neogit.buffers.log_view')`
or `:Neogit log` + `l`, waiting on the filetype and a graph row) and asserts
the wrap's desc and `commit_under_cursor()` on a commit row.

## R5 (stale statements) — the range invalidated text that `AGENTS.md` certifies as current, plus a set of comments and as-built entries §12 does not list

`AGENTS.md`'s preamble says *"'Key idioms' and everything from 'Testing' down
are current"*. Measured against HEAD, in that region:

* Key idioms: *"`lua/ucw/plugins/which-key.lua` keeps only group headers,
  core editor keys and the `<leader>l` tree (via `wk.add`)"*. There is no
  `<leader>l` tree; `<leader>l` is a single key (`:Lazy`), the LSP actions are
  `<leader>c`, and the file now also holds the `gr*`/`gO` rhs and two label-
  only blocks (T3). The bullet's "**Two traps**" also predates T2/T3: a new
  namespace's header needs a lowercase label, an explicit `icon` and
  `mode = { 'n', 'x' }` (§5 r4), and a mapping without a `desc` renders its
  rhs in the popup — the two rules the trial spent three commits on, absent
  from the file an agent is told to read first.
* Conventions: *"retrievable afterwards from `:Noice` / `<leader>nn`"* —
  `<leader>nn` no longer exists (D7: `<leader>n` history, `<leader>sm`
  search).

Same class, in code and tests this range edited:

* `tests/test_keys.lua` header: "`wk.add` … (group headers, core editor keys,
  the `<leader>l` tree)" and "for the **four** toggles" — the file's own census
  seventy lines down is titled *all seven toggles*. The visual-header case's
  comment says "Only the **five** headers with a visual-mode member are
  asserted"; the assertion lists **ten** (every header, rule 4). The comment
  describes a version of the case that was never committed.
* `lua/ucw/lsp/attach.lua` (twice) and `lua/ucw/lsp/actions.lua`: the inlay-
  hint toggle is still "`<leader>lI`" (it is `<leader>uh`, D4);
  `lsp/actions.lua` opens with "the global `<leader>l` tree".
* `lua/ucw/keys/actions.lua`: "`:Noice`/`<leader>nn`"; and the diagnostic-
  navigation comment argues no float on arrival is wanted because "Phase 4
  made `virtual_lines = { current_line = true }` the way full diagnostic text
  is shown" — T4 turned that default off in the same range. The same argument
  is in `phase9.5-trial-period.md` §6.1 ("`virtual_lines` already shows the
  text"), two sections after §4 retired it; T6's reasoning rests on a default
  T4 removed.
* `lua/ucw/plugins/iron.lua`: "the tree lived on `<leader>e`, freed for the
  explorer" — the explorer never kept it (T1).

In the design documents:

* `phase9.5-trial-period.md` §12 promises "that document now says so inline
  and points here", and lists `phase9-keybindings.md` §2.2 r2.1 (T6) and §5
  (T6/T7) as superseded. Measured: the only **(r4)** markers in
  `phase9-keybindings.md` are at §2.4, §2.5, §3 and §5's T2 paragraph;
  §2.2 has none, and §5's marker covers the header rules only. §7's as-built
  lines "D2c: snacks.words adopted highlight-only (no jump keys)" and "the
  buffer-local census … asserting both the **four** present keys" (six since
  T6) are unmarked and not in §12.
* `phase9.5-trial-period.md` §13's commit sequence ends at T10.2
  (`630e79f`/`2d15b98`); T11's `7380309`, `cebf98e`, `107cd15` and the
  `fold emulation` set they added to `tests/test_neotree.lua` are in the range
  and not in the as-built record. §7.3's "`q` was already the convention, in
  11 window kinds out of 13" does not match its own table (thirteen kinds in
  the `q` row, two in the `neither` row).

**Suggested fix.** The `AGENTS.md` bullet is the one that matters — it is the
instruction an agent follows before reading anything else, and it now sends
them to a tree that does not exist and omits the three header requirements.
The rest is a sweep by concept word (`<leader>l`, `lI`, `nn`, `four toggles`,
`five headers`, `virtual_lines … the way`, `explorer`), then the two inline
markers and the §13 tail. Recount rather than trust the numbers when
re-writing them.

## Not findings, checked and dismissed

* **`silent` parity holds across the range** — every `<leader>` key this
  config owns reads `si=1` in the snapshot; the `si=0` entries are Neovim's
  own defaults, blink's cmdline keys and lazy-load stubs, none relocated here.
* **D6 in this environment.** Injecting bytes into the tmux pane
  (`extended-keys on`, `TERM=tmux-256color`, no client attached): `0x09` →
  `<Tab>`, `\E[105;5u` → **`<Tab>`**, `\E[105;6u` → `<C-S-I>`, `\E[111;6u` →
  `<C-S-O>`, `0x0f` → `<C-O>`; tmux's own `C-i` key name also arrives as
  `<Tab>`. So the unshifted Ctrl-I is not distinct through a detached tmux
  server here, while the Shift pair is. That is the client-side prerequisite
  D6/T9.1 record (the Konsole keytab, absent from this machine), not a
  repo-side defect; the repo-side statement "nothing here breaks without the
  keytab — the keys arrive as `<C-o>`/`<C-i>`" holds (`<Tab>` still cycles
  buffers). Worth knowing before the next `<C-i>` measurement is made from a
  detached session.
* **The `<leader>go` header is `n`-only** while rule 4 says headers register
  for `n` and `x`. It has no visual-mode member and the visual census expects
  it absent, so the code and the test agree; only the rule's wording is
  broader than its instances.
* **`E776` from `:lopen` on an empty location list** is Neovim's, not a
  missing `q` mapping — the `qf` filetype covers the location-list window
  once one exists.
* **The lockfile moved (17 pins)**, deliberately: `e9a3db5` syncs every
  plugin, and T10.2/T11 re-pin `lazy.nvim`, `rustaceanvim` and neo-tree.
  `just lint` and both suite runs are green on those pins.
* **`<leader>?` (`wk.show { global = false })`** shows the attach keys in an
  LSP buffer, so P6's second door is real.
* **`Snacks.win`'s `q`** closes the `<leader>gm` float (`maparg('q').buffer ==
  1` inside it, back on `NeogitStatus` after the press), so `ucw.git`'s "q
  closes it" is measured, not assumed.

## Still open, unchanged by this review

* rustaceanvim's buffer-local `<leader>a` on the letter reserved for AI
  integration (`phase9-keybindings.md` §7, `phase9.5-trial-period.md` §14).
* `<leader>e`/`E` and the rest of §3's freed letters.
* The `zm`/`zx` nil guard in `ucw.neotree.helpers` stands on argument, not on
  a test (`phase9.5-trial-period.md` §11.3, deliberate).
* The Phase 10 rewrite of `AGENTS.md`'s history sections and
  `docs/architecture.md`; R5's "current" section is the part that cannot wait
  for it.
