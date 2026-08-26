# Phase 8 acceptance review (2026-08-15)

Independent audit of `46f5696..c4bef80` (four commits: r2 design doc, `aa0a3d8`
relocation, `face32e` toggles/octo/iron, r3 design doc), against
`docs/design/phase8-keymap-registration.md` r3. Everything below was measured
on this machine — two real TUI boots (pre-phase tree and HEAD) driven over
`--listen` sockets, plus deliberate breakage runs of the suite — rather than
read off the design document.

## Verdict

The relocation is correct where it was checked, and the checking was real: the
mapping *set* after the phase is exactly the pre-phase set plus the three octo
keys, and every claim in §6.3 reproduces on a second pair of hands. **Five
findings**, none of which breaks a key today, and three of which are the same
sentence: **the phase built its own instruments, and each instrument stops
exactly where the phase's attention stopped.**

* The invariant tool records `mode/lhs/rhs/desc` — so the one attribute that
  *did* change on 54 mappings, `silent`, is invisible to the check that was
  supposed to prove nothing changed (R1).
* The `desc`-fingerprint guard reads which-key's registry — so relocating
  keys out of that registry shrank its coverage from 85 entries to 31,
  including octo's, whose conversion it had been promised to cover "for
  free" (R2).
* The phase discovered that `keys =` silently makes a spec lazy and fixed it
  in five files; the suite catches the loss of `lazy = false` in exactly one
  of those five, and only by accident (R3).

§5 of the design document named this risk precisely — "relocation is where
regressions hide … it must cover modes and buffer-locality, the two attributes
silently droppable in a move". Modes and buffer-locality were covered. The
list had two items on it, and the attribute that actually moved was a third.

## What was re-verified and holds

* **Suite**: `just ci` twice on the tree as committed — **150/150, exit 0**,
  once in `~/.config/nvim` and once from a scratch worktree at `c4bef80`.
  `just lint` green ("Diagnosis completed, no problems found", 46 plugins
  present, 44 library entries); `just fmt-check` green.
* **The mapping set delta is exactly what §6.1 enumerates.** Independent
  snapshot (own script, `nvim_get_keymap` over `n/v/x/s/o/i/c/t`, `<Plug>`
  excluded, taken from a real TUI once the which-key queue had drained):
  **309 mappings before, 312 after; the only members added are `<leader>goo`,
  `<leader>goi`, `<leader>gop`; none removed.** rhs strings are byte-identical
  across the move except the enumerated stub/toggle/iron cases.
* **iron's `')` is gone in all six instances** (n/v/i × `<C-Enter>`,
  `<S-Enter>`); the pre-phase snapshot shows it present in all six, so the
  defect and its fix are both confirmed from the outside.
* **All four toggles work in both directions, driven by the real keys** in a
  live TUI (state read back over RPC after each press):
  `<leader>gtd` `show_deleted` false→true→false, `<leader>gtb`
  `current_line_blame` false→true→false, `<leader>lI` global
  `inlay_hint.is_enabled()` true→false→true, `<leader>lp` `virtual_lines`
  on→off and **back on from visual mode** (`v <leader>lp`), so D2 did not drop
  the second mode of the old lsp_lines binding.
* **The which-key popup really is stateful.** Captured from the tmux pane:
  `<leader>gt` renders `b ➜ Enable Current line blame` /
  `d ➜ Enable Show deleted`, `<leader>l` renders `I ➜ Disable Inlay Hints` /
  `p ➜ Disable Diagnostic virtual lines`, and the labels flip after a press.
  That is the whole point of D2 and it is delivered.
* **The `Snacks.toggle.get` factory-fallback trap, reverse-verified
  independently.** Changing `id = 'inlay_hints'` to anything else in
  `ucw.toggles` makes `tests/test_keys.lua`'s registry census fail *and* makes
  both P1-shaped cases in `tests/test_lsp.lua` fail (`is_enabled()` stays
  `true` after the toggle — P1 exactly). §6.3's claim is true as written.
* **The group-header census bites**: deleting the `<leader>go` header makes
  the case fail with a legible message.
* **The octo stub is functional, not just described.** Pressing `<leader>gg`
  (same shape, cheaper to verify end to end) loads neogit, opens
  `NeogitStatus`, and leaves the real `<Cmd>Neogit<CR>` behind in `maparg`.
* **`cond = false` targets are clean.** Booting with `vim.g.vscode = true`:
  no errors, `pcall` around the probe returns ok, gitsigns/bufferline/
  auto-session keys `ABSENT`, `<leader>lI`/`<leader>lp`/`<leader>bb`/`<M-h>`/
  `<leader>gg`/`<leader>nn` present, both core toggles registered. This is the
  enumerated embedded-target delta and nothing else. (`<Tab>` reads absent —
  the known `wk.add`-under-headless artifact, §6.2.)
* **The fake dependency edges are gone**: `which-key.nvim` no longer appears
  in any other spec's `dependencies`, which was one of D1's stated payoffs.
* **`Snacks.toggle:map`'s `mode` option is real** (`snacks/toggle.lua:118-122`
  strips `mode` and passes it to the map function), so `<leader>lp`'s
  `{ 'n', 'v' }` is not wishful thinking; and `Toggle:_wk` registering through
  `Snacks.util.on_module('which-key', …)` is order-safe because
  `which-key.init.add` only *queues* until `Config.setup`'s scheduled `load()`
  drains it (`which-key/config.lua:283`).

## R1 (method, and 54 mappings) — the invariant was proven with an instrument that cannot see options

`scripts/keymap-snapshot.lua` records `mode`, `lhs`, `rhs`-or-`<callback>`,
`desc`. `nvim_get_keymap` also returns `noremap`, `silent`, `expr`, `nowait`,
`replace_keycodes`, `script`, and one of them changed.

**which-key defaults every mapping it creates to `silent = true`**
(`which-key/mappings.lua:265`: `mapping.silent = mapping.silent ~= false`).
lazy.nvim passes through only the keys written in the spec
(`lazy/core/handler/keys.lua`, `M.opts` skips `mode/id/ft/rhs/lhs` and copies
the rest) and `vim.keymap.set` defaults `silent` to false. So *every* mapping
that moved from `wk.add` to `keys =` quietly lost `silent`.

Measured, pre-phase TUI vs HEAD TUI, full flag dump:

* **54 mappings flipped `silent=1 → silent=0`.** No other flag differs
  anywhere (`noremap`, `expr`, `nowait`, `replace_keycodes`, `script` are
  identical except on the lazy stubs, which are `expr=1 replace_keycodes=1` by
  construction — that part is enumerated).
* 50 of the 54 have a `<Cmd>…<CR>` rhs, which never echoes, so they are
  indistinguishable in practice.
* **4 do not**: `v <leader>gr`, `v <leader>gs` (`:Gitsigns …<CR>`) and
  `x ic`, `o ic` (`:<C-U>Gitsigns select_hunk<CR>`). These type a real command
  line, which is what `silent` exists to hide.
* **Visible effect today: none that could be captured.** With `cmdheight=0`
  and noice owning the cmdline, a non-silent `:cmd<CR>` mapping renders
  nothing — verified by mapping `:sleep 1500m<CR>` twice, once silent and once
  not, and capturing the pane mid-execution: identical screens.

So this is not a user-facing regression today. It is a finding because of what
it says about the check: the phase's central claim is "the full-phase diff is
exactly the enumerated deltas **and nothing else**", and the diff that proved
it could not have shown this class of change at all. The next relocation that
drops a `nowait`, an `expr`, or a `remap` gets the same green.

**Suggested fix.** Both halves: (a) `scripts/keymap-snapshot.lua` dumps the
option flags too (four extra fields, no new mechanism), and (b) either add
`silent = true` to the relocated entries — which makes the move byte-identical
and is what the phase said it was doing — or record the drop in §6.1 as a
sixth enumerated delta with the "invisible under `cmdheight=0` + noice"
measurement attached. Silently keeping it is the only option that is
inconsistent with the phase's own standard.

## R2 (test coverage) — the `desc`-fingerprint guard lost two thirds of its surface, including the file it was promised for

`tests/test_keys.lua`'s "no entry carries a right-hand side in its
description" iterates `require('which-key.config').mappings`. That registry
holds what `wk.add` put there — and D1's whole point is that most keys are no
longer added that way.

Measured on the two live instances (`Config.mappings` entries carrying an
`rhs`): **85 before the phase, 31 after.** The 54 that left are exactly the
relocated ones.

The sting is in `octo.lua`. Its pre-phase comment said, of the v1 block: *"When
it converts, `tests/test_keys.lua`'s 'no `desc` that looks like an rhs'
assertion covers it for free."* It converted in this phase — into `keys =`,
i.e. out of the registry that assertion reads. `<leader>goo/goi/gop` are now
outside the guard that was cited as the reason not to worry about converting
them.

And the failure mode survives the change of mechanism. In a lazy `keys =`
entry the rhs is also the second array element, so
`{ '<leader>x', desc = '<cmd>Foo<cr>' }` parses as a key with no rhs;
`Keys.resolve` keeps it (only `false`/`vim.NIL` remove an entry) and
`Keys:_set` is `if keys.rhs then …`, so after the plugin loads **the key is
simply not mapped** while which-key still shows the label. That is the Phase 1
`g[`/`g]` bug, reachable through the new front door.

**Suggested fix.** Make the guard mechanism-independent: scan
`vim.api.nvim_get_keymap` for descs matching the same fingerprint (`^<cmd>`,
`^<plug>`, `^:%a`), which covers `wk.add`, `keys =`, `Snacks.toggle` and
anything added next; keep the which-key sweep if the label-without-mapping
case is still wanted. Reverse-verify by planting one.

## R3 (test coverage) — the trap this phase discovered is guarded in one file out of five

§6.2's headline: *"`keys =` alone makes a spec lazy, so every eager spec that
gained keys also gained an explicit `lazy = false` (gitsigns, bufferline,
auto-session, navigator, iron)"*. Five files now carry a comment explaining
that the line is load-bearing. Nothing asserts it.

Measured by deleting the line, one file at a time, and running the full suite:

* **gitsigns without `lazy = false`: 1 failure** — but not a gitsigns test.
  `tests/test_keys.lua`'s toggle census fails on `gitsigns_deleted`, because
  the two gitsigns toggles are registered in `config()` and a lazy plugin's
  `config()` has not run. Correct outcome, incidental cause, and the message
  says nothing about eagerness.
* **bufferline without `lazy = false`: 150/150 green.** In a real TUI the
  same tree boots with **no tabline at all** (pane capture: the bufferline row
  is missing; `plugins['bufferline.nvim']._.loaded == false`) until some
  bufferline key is pressed. The suite is silent.
* By the same structure, `auto-session`, `navigator` and `iron` are unguarded
  too. auto-session is the worst of them: a lazy auto-session means **session
  autosave never arms**, which nothing on screen announces and which the user
  discovers by losing a session.

Every previous acceptance review in this project has landed on the same
sentence — the new tests guard the thing that was deliberately changed. Here
the deliberate change (registration moved) is guarded three ways, and the
mechanical precondition the phase itself discovered is guarded once, sideways.

**Suggested fix.** One case in `tests/test_keys.lua` (or `test_boot.lua`):
for `gitsigns.nvim`, `bufferline.nvim`, `auto-session`, `Navigator.nvim`,
`iron.nvim`, assert `require('lazy.core.config').plugins[name]._.loaded ~= nil`
at boot. Reverse-verify by deleting one `lazy = false` — measured above to be
otherwise green, so the case is provably not redundant.

## R4 (stale statement) — AGENTS.md still teaches the pre-Phase-8 mechanism, in a section it certifies as current

`AGENTS.md` opens with an explicit map of what to trust: *"**'Key idioms' and
everything from 'Testing' down are current**"*. Inside Key idioms:

> the bulk of leader bindings live in which-key
> (`lua/ucw/plugins/which-key.lua`) via `wk.add {...}`

After this phase that is inverted — 54 of 85 leader bindings live in their
plugin's spec, and `which-key.lua` is group headers, core editor keys and the
`<leader>l` tree. An agent reading the file as instructed will add its next
keymap to the wrong file, in the mechanism the phase moved away from. The
same bullet is also the natural home for the two things this phase learned the
hard way and that nothing else records for a newcomer: **`keys =` on a spec
makes it lazy unless `lazy = false` is explicit**, and **toggles are
`Snacks.toggle` objects, not keys with a `<cmd>` rhs**.

Same class, smaller blast radius: `tests/test_keys.lua`'s file header still
says *"Coverage for the global keymap declarations in `ucw.plugins.which-key`"*
and *"Everything else in which-key.lua is still hand-written"* — a description
of a third of the file it now heads, with the corrected version 70 lines
below (Phase 7 R3's exact shape: the overturned statement sitting where the
reader arrives first).

## R5 (minor) — two defects that the relocation passed over

D4 established the standard for this phase: a stray-characters bug in an rhs
is mechanism hygiene, fix it here. Two more were in the lines this phase
touched or listed, and neither is recorded in §7 next to octo's mislabelled
`<leader>gop`.

* **`[c` goes the wrong way in a diff.** Both hunk-motion mappings evaluate
  to `']c'` when `&diff`:
  `{ '[c', "&diff ? ']c' : '<cmd>Gitsigns prev_hunk<CR>'", … }`. Measured in
  the live TUI (`:windo diffthis`, then evaluating the mapping's expr):
  `&diff=true → "]c"`. Upstream gitsigns' own README uses `[c` on that branch.
  Pre-existing (Phase 1 or earlier), relocated verbatim into `gitsigns.lua` by
  `aa0a3d8` — i.e. the same copy-paste-remnant class as iron's `')`, in the
  same commit that fixed the iron one, one screen apart.
* **The `<leader>e` iron subtree has no group header** and its descs are
  identifiers: eight mappings (`<leader>e%`, `<leader>e<CR>`, `<leader>eF`,
  `<leader>ec`, `<leader>ef`, `<leader>el`, `<leader>eq`, `v <leader>ef`) with
  descs like `iron_repl_send_file`, registered by iron's own `setup()`. Not
  touched by this phase — but the new census test now *pins* their
  headerlessness by asserting the group list is exactly ten, so Phase 9 will
  meet it as a failing test rather than as a note. Worth a §7 line.

## Not findings, checked and dismissed

* **`silent` was the only flag that moved** — every other option matches
  across the phase (see R1's dump). No `nowait`/`remap`/`expr` surprises.
* **Duplicate lhs in one `keys =` table is safe.** `gitsigns.lua` lists
  `<leader>gr`/`<leader>gs` twice (normal and visual). lazy keys ids are
  `lhs .. " (" .. mode .. ")"` (`keys.lua` `M.parse`), so they do not collide;
  both survive in the snapshot.
* **`mode = { 'x', 'o' }` for the `ic` textobject** replaced two separate
  entries and produces the same two mappings, rhs and desc identical.
* **The new `dependencies` edges do not create a cycle or change laziness.**
  `which-key → snacks` and `gitsigns → snacks` only order two already-eager
  specs; snacks keeps its own `lazy = false` from its own spec.
* **`ucw.lsp.actions`' `toggle` kind is fully retired** — no caller, no
  annotation, no test referencing it remains.
* **The `<leader>gu` / `undo_stage_hunk` line moved verbatim**, deprecation
  suppression and Phase 7 R2's reasoning intact.
* **which-key registration order is not fragile.** `wk.add` before
  `wk.setup` is queued and drained at setup, so `Snacks.toggle`'s
  `on_module('which-key')` callback cannot lose its spec regardless of which
  eager plugin loads first.

## Still open, unchanged by this review

* `<leader>gop` labelled 'Search issues' (§7, kept verbatim on purpose).
* `which-key.lua` loading in embedded targets (§7, Phase 9 policy).
* neo-tree × Neovim 0.13 (`E216`, upstream, tracked by
  `tests/test_neotree.lua`).
