# Phase 8 acceptance review, second pass (2026-08-16)

A second, independent audit of `46f5696..c4bef80`, run after reading
`phase8-acceptance-review.md` (review 1, `cb2513a`) — so its job is different:
re-verify review 1's findings first-hand rather than trust the prose, and hunt
in the places review 1 did not look. Everything below was measured on this
machine in a live TUI unless said otherwise.

## Verdict on review 1: all five findings CONFIRMED

* **R1 (silent flags), confirmed by direct probe**: `maparg(..., 1).silent` on
  a relocated key vs a `which-key.lua` survivor: `<leader>gs` (n) = 0,
  `<leader>gr` (v) = 0, `ic` (o) = 0, while `<leader>tc` (still `wk.add`) = 1.
  The instrument criticism stands: `scripts/keymap-snapshot.lua` cannot see
  any of `nvim_get_keymap`'s option flags.
* **R5a (`[c`), confirmed by evaluation**: with two windows in `diffthis`,
  `eval(maparg('[c','n'))` → `]c` and `eval(maparg(']c','n'))` → `]c`. Both
  hunk motions go forward in a diff. Same remnant class as iron's `')`,
  missed by the same commit that fixed iron's.
* **R2, R3, R4** hold as written (R2/R3 re-checked by inspection of
  `Keys:_set`'s `if keys.rhs then` and the five `lazy = false` sites; R4 by
  reading AGENTS.md's "current" certification against the Key idioms bullet).
* **R5b** (`<leader>e` headerless, pinned by the ten-group census) —
  confirmed; recorded for Phase 9 in design doc §7 rather than fixed, per
  review 1's own suggestion.

## New material this pass adds

* **A1 — R2's suggested fix is under-specified and would ship red.** Review 1
  proposes scanning `nvim_get_keymap` descs for `^<cmd>`, `^<plug>`, `^:%a`.
  Measured on a clean boot: **`^:%a` has 33 false positives**, all Neovim's
  own default mappings, whose descs are *deliberately* command-shaped
  (`[b → ':bprevious'`, `& → ':help &-default'`, …). They cannot be filtered
  by script id either: `getscriptinfo({sid=-8})` errors — **Lua-defined
  mappings share the negative Lua sid**, ours and Neovim's alike. The fix
  implemented here narrows the colon classes to `^:%u` (our ex-command names
  are capitalized: `:Gitsigns`, `:AutoSession`) and `^:<` (`:<C-U>…`);
  measured zero false positives, and both planted-bug shapes are caught
  (reverse-verified in the fix commit).
* **A2 — clean checks review 1 did not record**, each measured:
  * No stale mechanism statements in any doc beyond R4's two: grepped
    README.md and docs/*.md for which-key/keymap claims — nothing.
  * `lazy-lock.json` is untouched across the whole phase (`git diff
    46f5696^..c4bef80 -- lazy-lock.json` empty) — no accidental plugin
    updates rode along (a Phase 6 hazard, `lazy.sync()`).
  * The R3 fix's predicate shape is sound: `plugins[name]._.loaded ~= nil`
    reads `true` for all eight eager specs in a real TUI boot
    (gitsigns/bufferline/auto-session/Navigator/iron/noice/snacks/which-key).
* **No sixth code defect found.** The surface review 1's set-plus-flags dump
  already covers (membership, rhs bytes, desc, every option flag) leaves
  little room; my remaining angles (docs, lockfile, spec-level `keys =`
  census, dependency edges) came back clean.

## Fix plan (applied in the commits after this one)

R1 both halves: the snapshot script dumps `noremap/silent/expr/nowait/
replace_keycodes` too, and every `keys =` entry this phase added gets
`silent = true`, restoring byte-and-flag parity with the `wk.add` originals
(the four `Toggle:map` calls likewise, so the *only* flag story of the phase
is "none"). R2: a mechanism-independent maparg fingerprint case with the A1
classes, alongside the surviving registry case. R3: an eagerness census over
the five specs that must stay `lazy = false` (reverse-verified via the
bufferline deletion review 1 measured green). R4: AGENTS.md Key idioms
bullet rewritten to the split model + the two hard-won rules; test_keys.lua
header rewritten. R5a: `[c` returns `'[c'` in diff mode. R5b + octo label:
design doc §7. Design doc → r4 with a §8 recording both reviews' outcomes.
