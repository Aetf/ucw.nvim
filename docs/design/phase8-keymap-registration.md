# Phase 8 design: keymap *registration*

> Revision history
>
> * **r2** (2026-08-15) — **decisions locked** (user). D1: (b), plugin-owned
>   `keys =`. D2: adopt `Snacks.toggle`, upstream-default notifications kept
>   (the notify-off variant was offered and not chosen). D3: octo via
>   `keys =` + eager group header. D4: fix the iron `')` defect in this
>   phase. D5: unchanged. One question raised and answered during the D1
>   discussion: *is there anything better than which-key?* Surveyed
>   (2026-08): the only credible alternative is `mini.clue` — actively
>   maintained, would shed one plugin since mini.nvim is already a
>   dependency, and adds hydra-style submodes; but it costs rewriting every
>   registration site into its clue format, and D2's stateful toggle display
>   is wired by snacks *to which-key specifically* (§1.4a), so it would
>   degrade to hand-written clues with no icon/color. hydra.nvim solves a
>   different problem (Phase 9 may still add it); legendary.nvim is archived
>   (§0). Decision: stay on which-key v3. Noted side-effect of D1(b): most
>   registration becomes plain lazy.nvim `keys =` + `desc` on real mappings
>   — portable to any clue UI — so which-key-specific surface shrinks to
>   group headers plus the snacks.toggle wiring, making a future migration
>   *cheaper*, not harder. §3 firmed up accordingly.
> * **r1** (2026-08-15) — proposal. §1 is measured on this machine today (file
>   inventory by reading every registration site, a live-TUI probe of
>   `Snacks.toggle` against the pinned snacks/which-key commits, pinned-source
>   reading of `snacks/toggle.lua`); §0's two external facts are read from the
>   upstream issue/docs, not from memory. §2 is the discussion agenda — nothing
>   below it is settled.

Scope, restated from the plan file so this document cannot drift from it:
this phase is about **where and how keymaps get registered**, not about what
they are bound to. *No content changes* — same lhs, same behavior, same
modes. Bindings themselves are Phase 9, deliberately separate so mechanism
review and binding review don't entangle in one diff.

## 0. Inputs that arrived after the plan file was written

The plan's Phase 8 section locked "which-key v3 (`wk.add`) is the single
canonical mechanism for anything with a leader prefix or a `desc`", noted it
was re-confirmed as of March 2026, and prescribed two concrete jobs: convert
`octo.lua`'s v1 `wk.register` straggler, and close octo's discoverability
gap with an eagerly-registered group header. Two things are new since:

* **legendary.nvim is dead** (mrjones2014/legendary.nvim#505: maintainer
  stepped away, repo archived read-only 2025-04-17 after a one-month call
  for a successor found nobody). It was the one plausible "unified keymap
  registry + command palette" alternative to the which-key approach. Two
  reasons it matters here beyond "one less option": the maintainer's stated
  replacement stack is **which-key.nvim + snacks.picker — exactly what this
  config already runs**, which is about as strong an external confirmation
  of the locked decision as exists; and it is the same bus-factor story that
  retired nvimd in Phase 1 — a single-maintainer registry DSL is a tech
  island no matter how good it is. Nothing to do, but the decision is now
  confirmed for a better reason than "still maintained".
* **`Snacks.toggle` exists in the snacks.nvim already pinned here**
  (`stable-11-g882c996` has `lua/snacks/toggle.lua` in full). It makes
  toggles first-class objects — `get`/`set` closures with a `:map()` — and
  integrates with which-key v3 so the popup shows **live state**: icon,
  color, and a `Disable …`/`Enable …` description that flips with the
  actual value. Today's toggles are write-only keys whose state is
  invisible until pressed. This is a registration mechanism for the toggle
  *class* of keys, so it belongs to this phase; *which* toggles exist and
  where they live stays Phase 9. Measured behavior in §1.4, including one
  trap that would have re-introduced a fixed bug (§1.4b).

## 1. What is actually true today (measured 2026-08-15)

### 1.1 Registration mechanisms in the tree — five, where the plan assumes three

1. **Native `vim.keymap.set`/`utils.map` in `lua/ucw/keys.lua`** — the
   low-level remaps (`0`/`^` swap, `<c-s>`, `<Esc>` clear, `j`/`k`, mouse,
   terminal). Plan says unchanged; agreed, not touched further here.
2. **The central `wk.add` file, `lua/ucw/plugins/which-key.lua`** (~250
   lines). Holds *both* core editor keys (tabs, windows, buffers, `g[`/`g]`)
   *and* keys belonging to eight other plugins: gitsigns, neogit, diffview,
   Navigator, bufferline, snacks pickers, auto-session, noice/notifier.
3. **Per-plugin `wk.add`/`wk.register` inside `config()`**: `iron.lua`
   (v3), `octo.lua` (the last v1 caller). So plugin-owned keys already live
   in *two* different places depending on the plugin — the split is not a
   design, it's an accident of when each file was last touched.
4. **The named-action layer `ucw.lsp.actions`** + its two consumers
   (`which-key.lua`'s `<leader>l` tree, `attach.lua`'s buffer-local `g`
   keys). This is the house's best pattern — single source of truth,
   press-time resolution that fails loudly by name — and is the reference
   model, not a problem.
5. **lazy.nvim `keys =`** — used only *inside* snacks picker window config
   (picker-local keys, not global registration). Zero use as a lazy-load
   trigger / global keymap declaration, even though it is the idiom every
   plugin README ships and which-key v3 auto-ingests.

### 1.2 The two prescribed fixes, confirmed still open

* `octo.lua:24` is v1 `wk.register` with the nested-table spec, flagged
  `---@diagnostic disable-next-line: deprecated`, handed over explicitly by
  Phase 7 §7. The discoverability gap is real: spec is `cmd = 'Octo'`, the
  registration runs in `config()`, so until the first `:Octo` the
  `<leader>go` subtree does not exist in which-key at all.
* The plan's other two v2 stragglers (`lsp/init.lua`, `nvim-tree.lua`) are
  confirmed gone — `wk.register` greps to exactly one site.

### 1.3 Toggle-shaped keys today — four, all write-only

| key | state it flips | current rhs |
|---|---|---|
| `<leader>lI` | inlay hints, **global flag** (P1 semantics) | `ucw.lsp.actions` `toggle = true` kind |
| `<leader>lp` | diagnostic virtual-lines mode | `ucw.keys.actions.toggle_virtual_lines` |
| `<leader>gtb` | gitsigns current-line blame | `<cmd>Gitsigns toggle_current_line_blame<CR>` |
| `<leader>gtd` | gitsigns show-deleted | `<cmd>Gitsigns toggle_deleted<CR>` |

None shows its state anywhere. `toggle = true` is a bespoke kind in
`ucw.lsp.actions` used by exactly one action (`toggle_inlay_hint`);
`toggle_virtual_lines` is a bespoke function; the gitsigns two are opaque
ex-commands. Four toggles, three mechanisms.

### 1.4 `Snacks.toggle` probed live (TUI, pinned commits, this machine)

Probe: `Snacks.toggle.new` with custom `get`/`set` reading/writing the
**global** inlay-hint flag, `:map('<leader>zp')`, then drive the real TUI.

* a) **It works as documented on the pinned versions** (which-key
  `stable-8-g3aab214`, snacks `stable-11-g882c996`): the mapping exists
  (`maparg` non-empty), the which-key popup renders
  `p ➜ Disable Inlay Hints (probe)` while the flag is on; pressing it flips
  the global flag (`is_enabled()` → `false`, verified over RPC) and the
  popup then renders `Enable Inlay Hints (probe)`. Dynamic `desc`/`icon`
  are delivered by `Toggle:_wk()` calling `wk.add` with *function*-valued
  `desc`/`icon` and `real = true` — v3-only machinery, consistent with the
  canonical-mechanism decision, not a second system beside it.
* b) **The built-in factory is a trap for this config**:
  `Snacks.toggle.inlay_hints()` hardcodes `{ bufnr = 0 }` in both `get` and
  `set` (`snacks/toggle.lua:206-217`) — a **per-buffer** toggle. This
  config's inlay-hint semantics are deliberately global-flag-with-mirroring
  (`attach.lua` seeds the global flag and re-asserts it per buffer; Phase 3
  acceptance P1 is the two-presses bug that shipped the last time
  global/buffer got mixed up). Adopting the factory would re-introduce P1
  with better cosmetics. If `Snacks.toggle` is adopted, the inlay-hint
  toggle must be a custom `new{}` over the same global
  `enable`/`is_enabled` pair the actions layer calls today.
* c) **Toggling notifies by default** (`Enabled/Disabled **name**` via
  `Snacks.notify`) — observed in the probe. New behavior vs today's silent
  toggles; per-toggle `notify = false` exists if unwanted.
* d) **Error visibility is preserved**: `Toggle:get`/`set` wrap the
  closures in `pcall` and route failures to `Snacks.notify.error` naming
  the toggle. Not the hard `error()` of the actions layer, but the same
  property that layer exists for — a broken upstream call fails *visibly by
  name* at press time instead of leaving an inert key.

### 1.5 Defects noticed while surveying (source-level; effects not yet measured)

* `iron.lua:39` and `:42`: both rhs strings end in a stray `')` **outside**
  the `<cr>` — `"<cmd>lua …iron_send_block()<cr>')"`. Those two characters
  are fed as keys after the command runs, in every mapped mode including
  insert. Looks like an editing remnant from a lua→string conversion.
* `iron.lua`/`octo.lua` carry `dependencies = { 'folke/which-key.nvim' }`
  edges (explicit or implied by calling `require('which-key')` in
  `config()`) solely because registration happens there.
* `which-key.lua` is `lazy = false` with no `cond`: the whole leader tree
  registers in every target, including vscode/firenvim embedded contexts.
  Whether that is *wanted* is a policy/content question — noted for Phase
  9, not touched here.

## 2. Decisions (answered 2026-08-15; see r2 note for the which-key-alternatives question)

* **D1 — Where does a plugin's keymap registration live?** Today it is
  §1.1's accidental split. Options: (a) keep the split; (b) **plugin-owned:
  each spec declares its own keys via lazy.nvim `keys =`** (with `desc`,
  which which-key v3 ingests automatically), reducing `which-key.lua` to
  group headers + core-editor keys + the cross-cutting `<leader>l` tree;
  (c) everything centralized into `which-key.lua`. **Decided: (b).** The
  reasons are the project's own: goal-wise, `keys =` is the format every
  plugin README ships (the same "copyable from upstream docs" argument that
  retired nvimd), it deletes the fake which-key `dependencies` edges, and
  it gives lazy-load-on-key for free where wanted. One-file-per-plugin is
  the house modularity rule; the central file putting gitsigns keys 200
  lines from the gitsigns spec is the deviation, not the norm. Strictly a
  *relocation*: same lhs/rhs/desc/modes move files, nothing is redesigned.
  The counterargument for (c) is "one place to read the whole tree" — but
  `:WhichKey`/`:checkhealth which-key` is that view, live and truthful.
  To be measured during construction: `keys =` semantics on `lazy = false`
  plugins (mapping creation timing), and on `cond`-disabled specs.
* **D2 — Adopt `Snacks.toggle` as the toggle mechanism?** **Decided: yes,
  same four toggles, same lhs, same semantics** — inlay hints via custom
  global-flag `new{}` (§1.4b, *not* the factory), virtual-lines wrapping
  the existing function's logic, the two gitsigns ones only if their state
  is cleanly readable (`require('gitsigns.config').config.…` — to be
  measured; if not, they stay as-is, adopting the mechanism does not
  require force-fitting every toggle into it). This retires the
  single-user `toggle = true` kind from `ucw.lsp.actions` (a bespoke kind
  fewer) and makes toggle state visible in the popup. Open sub-questions:
  where do toggle definitions live (proposal: with their owners per D1 —
  LSP ones near the LSP tree, gitsigns ones in `gitsigns.lua`); keep or
  silence the new toggle notifications (§1.4c — proposal: keep, it is
  upstream default behavior and cheap to revert).
* **D3 — octo.** The plan prescribes wk.add conversion in `config()` plus
  an eager group header. Under D1(b) there is a strictly better shape:
  the three bindings become spec `keys =` entries (they are plain
  `<cmd>Octo …<cr>` strings, ideal lazy-load triggers alongside
  `cmd = 'Octo'`), plus the eager `<leader>go` group header. That closes
  the discoverability gap *fully* — the keys themselves are visible and
  functional before octo ever loads, not just the group label.
  **Decided: `keys =` + eager group header.** (If D1 lands on (a)/(c),
  fall back to the plan's original prescription.)
* **D4 — the iron `')` defect (§1.5).** Fixing a stray-characters bug in an
  rhs is mechanism hygiene, not a binding redesign. **Decided: fix in this
  phase**, with a before/after behavior check since the effect is currently
  unmeasured.
* **D5 — buffer-local LSP keys (`attach.lua`) and `ucw.lsp.actions`:
  no change.** Named as the reference pattern; D2 only removes the
  `toggle` kind, the action table and both consumers stay as they are.

## 3. Proposal (as decided)

1. **Snapshot first** (§3.4's tool is built before anything moves): dump
   every mapping — mode, lhs, rhs-or-callback identity, desc,
   buffer-locality — from a booted full-UI instance to a file. This is the
   baseline the whole phase is diffed against.
2. **Relocate plugin-owned keys per D1(b)**, plugin by plugin: gitsigns
   (incl. the visual `<leader>gs`/`<leader>gr` variants and the `ic`
   operator/visual textobject), neogit, diffview, Navigator (n and t
   modes), bufferline, snacks pickers, auto-session, noice/notifier —
   each spec grows `keys =` entries carrying today's exact lhs/rhs/desc/
   mode; `which-key.lua` shrinks to group headers, core editor keys
   (tabs/windows/buffers, `g[`/`g]`), and the `<leader>l` tree. Each
   plugin's existing load trigger is kept — relocation does not opt anyone
   into key-triggered lazy loading (octo is the one deliberate exception,
   step 4). `keys =` semantics on `lazy = false` and `cond`-disabled specs
   get measured before the first relocation, not assumed.
3. **Toggles per D2** in a new `lua/ucw/toggles.lua` (definitions callable
   from specs per D1 ownership): inlay hints as custom `new{}` over the
   global `enable`/`is_enabled` pair (§1.4b), virtual-lines wrapping the
   existing logic, gitsigns blame/deleted only if their state reads
   cleanly; retire the `toggle = true` kind from `ucw.lsp.actions`;
   notifications stay at upstream defaults.
4. **octo per D3**: the three bindings become spec `keys =` lazy-load
   triggers alongside `cmd = 'Octo'`, `<leader>go` group header registered
   eagerly; the v1 `wk.register` block is deleted. **iron per D4**: drop
   the stray `')`s, with a before/after behavior check; the now-pointless
   which-key `dependencies` edges on iron/octo go away.
5. **Mechanical-equivalence check**: re-snapshot, diff against step 1's
   baseline; the diff must be empty except the enumerated, intended deltas
   (octo keys now exist at boot; toggle descs became dynamic; iron rhs
   lost two characters). This is the phase's core invariant — "no content
   changes" as a measured statement, not a promise.

## 4. Verification plan

* `tests/test_keys.lua` grows: (i) a boot-time assertion that every
  expected leader group is present in which-key (octo's included, plugin
  unloaded); (ii) a toggle assertion in the §1.4 probe's shape — press the
  real lhs, global flag flips, which-key desc flips; the existing generic
  "no rhs in a `desc`" assertion already covers the v1→v3 conversion
  fingerprint. Every new test reverse-verified (house rule F5).
* TUI: `:WhichKey` opens error-free; screenshots of `<leader>`,
  `<leader>g`, `<leader>l` trees before/after — groups all visible at boot.
* The §3.4 mapping snapshot diff, run in both the full-UI and (spot-check)
  embedded targets.
* Full suite green ×2 (house rule: once is not a signal).

## 5. Risks

* **Relocation is where regressions hide** — Phase 5's acceptance verdict
  ("findings land on what was moved incidentally, not what was changed
  deliberately") applies verbatim to a phase that is *mostly* relocation.
  The §3.4 snapshot diff exists precisely for this; it must cover modes and
  buffer-locality, the two attributes silently droppable in a move
  (`<leader>gs` visual variant, the `ic` operator-pending textobject).
* `keys =` changes *when* mappings come to exist for lazy plugins (stub at
  startup, real mapping at load). For octo that is the intended fix; for
  any other plugin that moves onto key-triggering, load-order behavior
  must be checked, not assumed — default stance is to relocate keys
  without changing each plugin's existing trigger.
* `Snacks.toggle` keeps state via closures; a toggle whose underlying state
  is *also* changed elsewhere (inlay hints, by `:LspRestart` interplay in
  `attach.lua`) shows stale icon only until the next popup render — desc
  and icon are re-evaluated at render time (§1.4a), so this is
  self-correcting; noted so nobody "fixes" it with an autocmd.
* which-key upstream is a moving `main` (pinned `stable-8-g3aab214`);
  dynamic `desc`/`icon` + `real = true` is snacks-coupled machinery. Both
  are folke-maintained and co-released in the same distro (LazyVim), which
  is as low as cross-plugin coupling risk gets in this ecosystem.

## 6. Observed, out of scope

* `_G.UCW.jump_textobject` global + `<Cmd>lua UCW.…<CR>` string rhs built in
  `mini.lua`, and the vendored `H.echo` mini.ai helpers in
  `ucw/keys/actions.lua` — content cleanup, Phase 9/10 territory.
* `which-key.lua` loading in embedded targets (§1.5 last bullet) — Phase 9
  policy question.
* Group icons/`wk_desc` cosmetics — Phase 9, with the bindings themselves.
