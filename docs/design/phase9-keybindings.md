# Phase 9 — Keybindings themselves

> **r2 — decisions recorded.** r1 (proposal) was reviewed interactively on
> 2026-08-16, one decision at a time (D1–D10), with a live preview session:
> `/tmp/phase9-preview.lua` layered the proposed D1 keys onto a real TUI
> (tmux session `phase9`) and the user exercised them before deciding.
> All ten decisions are resolved below. **No implementation has started.**
> Measured facts come from a live TUI snapshot taken on the Phase 8 tree
> (`scripts/keymap-snapshot.lua`, 312 global mappings, 2026-08-16) plus
> `ucw/lsp/attach.lua`'s buffer-local set read from source, plus the
> layered `<C-i>` probes recorded in §2.6.
>
> **r3 — as-built (2026-08-17).** Implemented in 13 commits on top of the
> doc commit, one namespace move per commit in the §6 dependency order,
> each verified by TUI snapshot diff (see §7 for the enumerated deltas and
> the divergences found during construction). 312 → 324 global mappings.
> Real-session trial runs next; acceptance review after that.
>
> **r2.1 — audit amendments (2026-08-16).** An independent design audit
> re-verified every measured claim against the live config (iron key
> meanings, native `grx`/`grt` on 0.12.4, target prefixes free, `<M-f>`/
> `<M-F>` rhs) — all held — and found one real collision and one
> verification blind spot: blink.cmp already owns insert `<C-k>` for
> signature help (§2.1 amended: signature stays with blink, no new key)
> and the global-only snapshot cannot see §2.1's buffer-local deltas
> (§6 amended). Recording gaps fixed in §0/§1.1/§2.2/§2.3/§2.9/§3/§5/§6.
> Decisions D1–D10 otherwise stand.

## 0. What this phase is for (goals recap)

Phase 8 fixed *where keys are registered* (specs own their `keys =`,
which-key.lua owns group headers, toggles are `Snacks.toggle`). Phase 9 owns
the *content*: which keys exist and what they mean. From the project's
original goals this is goal 7 ("redesign the keymap system"), and it
inherits the deciding argument of the engine migration:

> A bespoke schema with no external reference material never lowered the
> friction it promised to lower — you still have to memorize it, alone.

Applied to keys: **a bespoke key vocabulary is a tech island exactly the way
`nvimd`'s unit schema was.** Every key that matches what Neovim ships or
what the dominant community layout uses is a key whose answer exists outside
this repo (docs, muscle memory, other machines, other people's configs).
Every deviation is a private fact to maintain. Principle hierarchy:

- **P1 — Vocabulary**: Neovim *native defaults* first (`gr*`, `gO`, `K`,
  `[d]d`, `]q`, `gc`), the de-facto community layout (LazyVim's leader
  namespaces) second, existing local habit third. Deviate only with a
  stated reason, recorded here.
- **P2 — Ergonomics**: common operations ≤ 2 keys after the prefix;
  lowercase = common case, Capital = wider-scope variant of the same verb
  (`<leader>gs`/`<leader>gS` stage hunk/buffer, `bx`/`bX` — kept and
  documented; not to be confused with the *global* `gS` edge-jump D1
  deletes, nor lightspeed's `gs`); highest-frequency actions also get a
  non-leader accelerator.
- **P3 — Don't shadow native motions/operators** unless the replacement
  strictly supersedes them *and* is community-mainstream. Lightspeed's
  `s`/`S` stays. The accidental shadows found in §1.2 get fixed.
- **P4 — Discoverability**: every namespace has an eager which-key group
  header; every mapping has a quality `desc` (test-enforced); stateful
  keys are `Snacks.toggle`s so which-key shows their state.
- **P5 — Extensibility**: a new plugin's keys go in its spec's `keys =`;
  the namespace comes from the domain table in §5.
- **P6 — Searchability**: `<leader>sk` keymap picker + `<leader>?`
  buffer-local popup. Verified available: `snacks.picker.keymaps` and
  `which-key.show` are both functions in the running config.

## 1. Measured current state (unchanged from r1)

### 1.1 Leader namespaces today

| prefix | meaning | keys |
|---|---|---|
| `<leader>T` | picker | `Th` command history — *only member* |
| `<leader>b` | buffer | `bb` picker, `bd` pick-close, `bx`/`bX` delete |
| `<leader>e` | iron REPL | `e%` `e<CR>` `eF` `ec` `ef` `el` `eq` (+v `ef`); no header, identifier descs |
| `<leader>g` | git | hunk/buffer ops, `gg` Neogit, `gh` file history, `gt*` toggles, `go*` octo |
| `<leader>l` | LSP | 14 actions + 2 toggles (`lI`, `lp`) |
| `<leader>n` | notifications | `nd` dismiss, `nh` history, `nn` search |
| `<leader>s` | session | `sc` save, `sr` restore, `ss` search |
| `<leader>t` | tab | `tc` `tn` `to` `tp` `tx` |
| `<leader>w` | window | `wh` (=vsplit!) `wv` (=split!) `wx` |
| `<leader>`` | alternate buffer | (desc typo: "Alternvative") |

Non-leader: `<Tab>`/`<S-Tab>` buffer cycle, `\`/`|` neo-tree, `<C-p>` files,
`<M-f>` buffer lines ("Find in File"), `<M-F>` cwd grep ("Find in CWD"),
`<M-hjkl>` window nav, `<M-HJKL>` move line,
`<C-`>` terminal, `<C-s>` save, `<C-CR>`/`<S-CR>` REPL send,
`cs`/`ds`/`ys` surround, lightspeed, `<CR>`/`<BS>` folds, `[`/`]` families.

### 1.2 Findings — conflicts and drift

- **F1 — three parallel LSP layers.** Native 0.11+ defaults (`gra` `gri`
  `grn` `grr` `grt` `grx` `gO`) + the buffer-local `g` set from
  `attach.lua` (`g0 gW ge gD gd gt gH gr` + `<M-CR>` `<M-S-r>` `<C-k>`) +
  the `<leader>l` tree. Accidental shadows of native motions/commands in
  every LSP buffer: `ge` (backward word-end), `g0` (display-line start),
  `gt` (next tab); `gr` sits on the native `gr*` prefix (ambiguous, fires
  only after `timeoutlen`). Globally, `gE`/`gS` (mini.ai edge-jump opfuncs
  in `mini.lua`) shadow the native `gE` motion.
- **F2 — `<Tab>` = bufnext shadows `<C-i>`** — resolved by measurement,
  see §2.6.
- **F3 — picker keys scattered**: group `<leader>T` has one member; real
  pickers live on `<C-p>`, `<M-f>`, `<M-F>`, `<leader>bb>`, `<leader>ss`.
- **F4 — `<leader>e` (iron)**: no group header, identifier descs
  (Phase 8 handoff R5b). Community `e` is "explorer".
- **F5 — toggles scattered**: `<leader>lI`, `<leader>lp`, `<leader>gtb`,
  `<leader>gtd` in two unrelated trees.
- **F6 — `<leader>s` = session** collides with community `s` = search.
- **F7 — window tree semantics crossed**: `wh` runs `:vsplit` ("desc:
  horizontally"), `wv` runs `:split` ("vertically").
- **F8 — label debt**: octo `<leader>gop` says 'Search issues' (is PR
  search), "Alternvative" typo, iron descs.
- **F9 — no engine keys**: `:Lazy` unbound.
- **F10 — no searchability keys**.

## 2. Decisions (all resolved 2026-08-16)

### 2.1 D1 — LSP keys: native `gr*` vocabulary ✔ adopted

Tried live in the preview session before deciding. Final set:

| key | action | rhs |
|---|---|---|
| `gd` | definitions | `picker: lsp_definitions` |
| `gD` | declaration | `lsp: buf.declaration` (was implementations!) |
| `grr` | references | `picker: lsp_references` |
| `gri` | implementations | `picker: lsp_implementations` |
| `grt` | type definitions | `picker: lsp_type_definitions` |
| `grn` / `gra` / `grx` | rename / code action / codelens | native, untouched |
| `gO` | document symbols | `picker: lsp_symbols` |
| `K` `[d` `]d` `<C-w>d` | | native, untouched |
| (signature help) | **stays with blink.cmp** | no new key — see the r2.1 bullet below |

- **Deleted**: buffer-local `gr` `ge` `g0` `gt` `gH` `gW` (shadows /
  prefix ambiguity) and `<M-S-r>` (redundant with `grn`); global `gE`/`gS`
  mini.ai edge-jumps (shadow native `gE`; `[al`-family covers the
  functionality). Workspace symbols' only door becomes `<leader>sS`.
- **Kept accelerators**: `<M-CR>` code action, `n_<C-k>` diagnostics float.
- **Signature help: no new binding (r2.1, audit).** r2 planned `i_<C-k>` →
  native signature help, unaware that blink.cmp already owns that exact
  key: the `'enter'` preset binds insert `<C-k>` to show/hide_signature
  and `signature = { enabled = true }` is on (blink-cmp.lua) — blink's
  insert keymaps never reach the global mapping table, which is why the
  312-mapping snapshot didn't surface it. A native binding on top would
  stack two signature floats on one key. **Decision: signature help is
  blink's job** — `<C-k>` toggle plus automatic display on trigger chars;
  attach.lua adds nothing. Recorded shadows (P1): native `i_<C-s>`
  signature help stays shadowed by the save key; blink's `<C-k>` shadows
  the native digraph entry `i_CTRL-K` wherever a signature is available
  (blink falls through to digraphs elsewhere) — pre-existing since blink
  adoption, accepted.
- Picker rhs stay `ucw.lsp.actions` names (press-time resolution + tests).

### 2.2 D2 — `<leader>l` → `<leader>c` (code); `<leader>l` = `:Lazy` ✔

- `<leader>c`: `ca` code action (n,x), `cr` rename, `cf` format (n,x),
  `cl` codelens run. Letters match LazyVim exactly.
- **No goto/list duplicates under leader** — `gr*` shapes are the only
  door (the 6 redundant entries `ld lD lt lH lr l0` die with the tree).
- **document highlight goes automatic**: replace `lh`/`l<C-L>` manual
  keys with automatic reference highlighting. Implementation note:
  evaluate snacks' built-in `words` module first (already-pinned plugin,
  also gives `]]`/`[[` reference jumps) before hand-rolling CursorHold
  autocmds. Behavior change — measure in TUI at implementation time.
  P3 note (r2.1): the conventional `]]`/`[[` jump keys (LazyVim's
  binding) shadow the native section motions — if the jumps are adopted,
  record that shadow here with its reason; adopting `words` for
  highlighting only, without the jump keys, is the shadow-free option.
- `<leader>l` (freed) = `:Lazy` — literally LazyVim's own binding.
  `:checkhealth ucw` stays keyless (low frequency).

### 2.3 D3 — `<leader>f` find + `<leader>s` search; sessions → `<leader>q` ✔

- `<leader>f`: `ff` files, `fr` recent, `fg` git files. **No `fb`** —
  buffers stay `<leader>bb` only (user choice: one door).
- `<leader>s`: `sg` grep, `sb` buffer lines, `sw` word under cursor
  (n; x = grep the selection, LazyVim-shaped, r2.1),
  `sc` command history (←`Th`, T group dissolves), `sm` messages
  (←`nn`), `ss` document symbols, `sS` workspace symbols (both kept —
  search semantics, not goto duplicates), `sd`/`sD` buffer/workspace
  diagnostics, `sk` **keymaps picker**, `sh` help, `s<space>`
  **picker-of-pickers** (`Snacks.picker()`) — unbound long-tail sources
  all reachable here, which is what keeps the tree small.
- **`<C-p>` rhs upgrades to smart files** (frecency); `<leader><space>`
  stays unbound (user choice — accelerator upgraded instead).
  One-door guard (r2.1): snacks' `smart` source defaults to
  `multi = { buffers, recent, files }` — open buffers would quietly get a
  second door through `<C-p>`, contradicting the `fb` rejection above.
  Configure `finders = { 'recent', 'files' }` (frecency/cwd boosts are in
  the matcher and survive this).
- `<leader>q`: `qs` save, `qr` restore, `ql` list/search sessions, `qq`
  quit all. Letter note (r2.1): LazyVim's `qs` means *restore*; here the
  `s`ave/`r`estore pair is self-describing and auto-session makes explicit
  save meaningful — deviation recorded per P1.
- Accelerators `<M-f>`/`<M-F>` keep their rhs (= `sb`/`sg`).

### 2.4 D4 — all toggles → `<leader>u` ✔ (+3 new)

`uh` inlay hints (←`lI`), `uv` diagnostic virtual lines (←`lp`),
`ub` git blame line (←`gtb`), `ud` git show-deleted (←`gtd`), plus new:
`uD` diagnostics master switch, `uw` wrap, `us` spell. Also `un` dismiss
notifications (from D7). `<leader>gt` subtree dissolves. Only `uh`
letter-matches LazyVim; prefix-level convention is what carries.
Implementation note: inlay hints keeps Phase 8's custom global toggle —
snacks' built-in factory is per-buffer (P1 regression risk, census
guards it).

### 2.5 D5 — iron → `<leader>r` (REPL); explorer takes `<leader>e`/`E` ✔

| new | was | action |
|---|---|---|
| `rr` | — | **open/toggle REPL (new — there was no key!)** |
| `rf` | `e%` | send file |
| `rl` | `eF` | send line |
| `rs` (n) | `ef` | send motion |
| `rs` (v) | `ef` (v) | send selection — mode-symmetric |
| `rc` | `ec` | interrupt (cancel) |
| `rx` | `el` | clear |
| `rq` | `eq` | exit |
| `r<CR>` | `e<CR>` | send CR |

All descs rewritten as prose (R5b). `<C-CR>`/`<S-CR>` unchanged.
`<leader>e` = neo-tree toggle+reveal (=`\`), `<leader>E` = focus (=`|`);
both accelerators stay.

### 2.6 D6 — `<Tab>`/`<S-Tab>` stay; `<C-i>` recovered via environment ✔

Layered measurement (all live, 2026-08-16):

1. Baseline: user's Ctrl-I cycled buffers — indistinguishable.
2. tmux `extended-keys` was `off`; turned `on` + committed to tmux.conf
   (yadm `00a67bf`). Inner hop then **proven working**: `tmux send-keys
   C-i` fired a distinct `<C-I>` mapping in nvim while `<Tab>` kept its
   own (nvim's mapping table distinguishes them unconditionally; the
   terminal decides what arrives).
3. Still broken end-to-end: **Konsole supports no extended keyboard
   protocol at all** (kitty protocol is an open feature request, KDE Bug
   512065, no implementation; the `konsole*:extkeys` line in tmux.conf
   was a wishful manual declaration).
4. **User fixed it client-side**: custom Konsole keytab entry making
   Ctrl+I emit the extended escape sequence. Re-measured: distinct. ✔

Environment prerequisites recorded: tmux `extended-keys on` (yadm
`00a67bf`) + the user's Konsole keytab (client machine, user-maintained).
Caveat: the keytab emits unconditionally, so non-tmux apps that don't
speak CSI-u will see garbage on Ctrl-I; inside tmux everything is
re-encoded per inner app. Repo-side: **no change** — Tab/S-Tab keep
cycling, jumplist forward works again.

### 2.7 D7 — notifications tree dissolves ✔

`<leader>n` = single key, notification history (LazyVim-style);
`<leader>un` dismiss (u tree); `<leader>sm` search (D3). `n` prefix freed.

### 2.8 D8 — submodes/hydra: skipped ✔

Evaluated per Phase 8 handoff. Every classic submode use case already has
a cheaper answer here (`<M-hjkl>` nav, `]c`/`[c` two-key no-prefix, Tab
single-key). New plugin = new tech island; which-key v3 deliberately
doesn't do sticky modes. Re-open clause: only on a concrete measured pain
point during the trial period, and prefer promoting hot keys to
prefix-less mappings before reaching for a plugin.

### 2.9 D9 — which-key: not in vscode, kept in firenvim ✔

`cond = not is_vscode` — vscode-neovim renders no nvim floats and owns
buffers/windows/tabs itself (upstream recommends disabling UI plugins);
firenvim is a real UI where discoverability matters most. Enabling
cleanup: after D1, `attach.lua`'s remaining custom keys (`gd`/`gD`/
accelerators — no `i_<C-k>`, signature is blink's per §2.1 r2.1) switch
to bare `vim.keymap.set`, removing
attach.lua's `require('which-key')` — the same "bare require of a
deliberately-absent plugin" seam as Phase 6 R1. Verify with the Phase 8
embedded-target census pattern; re-check the "no floats in vscode" claim
in the real environment at implementation time.

### 2.10 D10 — window tree: minimal fix, `<C-w>` letters ✔

`ws` = `:split` (=`<C-w>s`), `wv` = `:vsplit` (=`<C-w>v`), `wx` close.
`wh` deleted. Note `wv` flips meaning (was horizontal) — accepted for
letter-alignment with native vocabulary. Other window ops stay on
`<M-hjkl>` + which-key's `<C-w>` preset. LazyVim's `<leader>-`/`|` split
keys rejected (`|`/`\` are neo-tree accelerators here).

## 3. Resolved layout (implementation blueprint)

| prefix | domain | members |
|---|---|---|
| `<leader>b` | buffer | `bb` picker, `bd` pick-close, `bx`/`bX` (unchanged) |
| `<leader>c` | code | `ca` `cr` `cf` `cl` |
| `<leader>e`/`E` | explorer | toggle / focus (accel `\`, `|`) |
| `<leader>f` | find | `ff` `fr` `fg` |
| `<leader>g` | git | unchanged minus `gt*`; octo desc fixed |
| `<leader>l` | plugin manager | `:Lazy` |
| `<leader>n` | notifications | single key: history |
| `<leader>q` | quit/session | `qs` `qr` `ql` `qq` |
| `<leader>r` | REPL | `rr` `rf` `rl` `rs` `rc` `rx` `rq` `r<CR>` |
| `<leader>s` | search | `sg` `sb` `sw` `sc` `sm` `ss` `sS` `sd` `sD` `sk` `sh` `s<space>` |
| `<leader>t` | tab | unchanged |
| `<leader>u` | toggles+UI | `uh` `uv` `ub` `ud` `uD` `uw` `us` `un` |
| `<leader>w` | window | `ws` `wv` `wx` |
| `<leader>?` | searchability | which-key buffer popup |
| `<leader>`` | alternate buffer | unchanged (typo fixed) |

Dissolved: `<leader>T`, `<leader>gt`, `<leader>n` (as tree), old
`<leader>l`/`<leader>e`/`<leader>s` meanings.
Freed for the future: `a d h i j k m o p v x y z` + most capitals —
of which `d` is earmarked for the debugger goal and `a` for the optional
AI-integration goal (both still ahead in this project, both LazyVim's
letters; r2.1).

Non-leader deltas: `<C-p>` → smart files (buffers excluded, §2.3);
buffer-local LSP set per §2.1 (signature help stays blink's `<C-k>`,
no new key); `gE`/`gS` deleted; everything else stays.

Leftover not covered by D1–D10 (r1 §3 had it): a `<leader>x`
quickfix/loclist tree. Default: **skip** — diagnostics pickers live at
`sd`/`sD`, list navigation at `]q`/`[q` etc.; revisit if missed in trial.

## 4. Label/content debt folded into implementation

octo `<leader>gop` desc → "Search pull requests"; "Alternvative" typo;
iron descs (§2.5); group census + desc-fingerprint tests updated with
each namespace commit.

## 5. The extension rule (P5, the durable artifact)

When a new plugin arrives, its keys go in its spec's `keys =`; the prefix
comes from this table, not from the plugin's README defaults:

| the feature is… | it goes under |
|---|---|
| a picker/search over anything | `<leader>s` (or `<leader>f` if it opens files); long tail: no key, reachable via `s<space>` |
| an action on the code under the cursor | `<leader>c` / native `gr*` shape |
| git-anything | `<leader>g` |
| an on/off state | `Snacks.toggle` under `<leader>u` |
| buffer/window/tab lifecycle | `<leader>b` / `<leader>w` / `<leader>t` |
| an interactive tool with its own UI (REPL-like) | `<leader>r` or a new free prefix |
| a motion/textobject | non-leader, native-shaped, P3 applies |
| the debugger (upcoming goal) | `<leader>d` — reserved, don't squat it |
| AI integration (upcoming goal) | `<leader>a` — reserved, don't squat it |

New namespace ⇒ claim a free prefix (§3), add the eager group header in
which-key.lua, and add it to the group census in `tests/test_keys.lua` —
the census failing is the designed reminder that this table needs a row.

## 6. Verification plan (when implementation is approved)

- Snapshot diff (`scripts/keymap-snapshot.lua`) before/after per commit;
  every delta enumerated in this doc's r-final, Phase 8 style.
- **Buffer-local keys need their own instrument (r2.1, audit).** The
  snapshot script reads only the global mapping table — every attach.lua
  delta in §2.1 (11 keys deleted/changed, the largest single chunk of
  this phase) is invisible to it, and no test asserts the post-attach
  buffer key set. Without a second instrument the snapshot certifies D1
  over a class of change it cannot see — the Phase 8 R1 failure mode
  again. Add a buffer-local dump (`nvim_buf_get_keymap` on an
  LSP-attached buffer, before/after) or a test_keys assertion of the
  post-attach set, landed with the D1 commit.
- One commit per namespace move, bisectable/revertible; each updates the
  test_keys group census in the same commit.
- **Reused prefixes order the commits (r2.1)**: `e` (iron out → explorer
  in), `s` (session out → search in), `l` (LSP tree out → `:Lazy` in),
  `n` (tree out → single key in) — each move-out commit must precede its
  move-in commit, or the intermediate tree double-registers the prefix
  and the per-commit snapshot diff turns to noise.
- D9's vscode gating verified with the embedded-target census pattern.
- Real-session trial: run the new layout for several days before
  acceptance review; expect label/placement tweaks as their own commits.
- `<C-i>` end-to-end re-check after any tmux/Konsole config change.

## 7. As-built record (r3, 2026-08-17)

Commit sequence (`c7abf52` doc, then): `ae3ceec` D1 → `d3d1b41` D2a
(l-tree→c) → `9944d27` D2c (words) → `5b3049c` D4 (u tree) → `eff1a71`
D2b (l=:Lazy) → `5746098` D3a (s→q) → `c9e4ef0` D3b (s=search) →
`14533f7` D3c (f tree) → `0c85db4` D7 (n single) → `cd2f4c7` D5a
(e→r) → `615e5e6` D5b (e=explorer) → `a6f076c` D10 → `3d96f1d` D9 →
`b497c5f` labels/`<leader>?`. Every commit's global-snapshot diff
contained exactly its enumerated delta (the per-commit diffs are in the
commit messages' claims; snapshots were taken from a fresh TUI boot each
time after one diff picked up an `i_<CR>` autopairs mapping from
interaction history — the Phase 8 "same interaction history" caveat,
re-confirmed). Global count: 312 → 324.

Divergences and findings from construction, none changing a decision:

- **D1: deleting `gS` did not free the key** — lightspeed's own
  `<Plug>Lightspeed_gS` (cross-window jump, pairing the existing `gs`)
  resurfaced from under the shadow. Better than a free key: it is the
  plugin's native vocabulary (P1).
- **D1 instrument**: the buffer-local census lives in tests/test_lsp.lua
  ("the buffer-local key set is exactly the D1 set"), asserting both the
  four present keys and the seven deleted ones staying gone.
- **D2c**: snacks.words adopted highlight-only (no jump keys), per the
  r2.1 note. Measured live: 4 reference marks on a symbol, 0 on a
  comment line, namespace `nvim.lsp.references`.
- **D3b**: smart.Config's annotated `finders` field has **no consumer**
  in the pinned snacks; the composition mechanism is `multi`. `<C-p>`
  ships `multi = { 'recent', 'files' }`, verified live
  (`p.opts.multi`), so buffers keep their one door.
- **D5a**: iron hardcodes identifier descs (`core.lua:832`) with no
  override, and every `named_maps` rhs is a thin public-API wrapper — so
  the keys are bound in the spec's `keys =` with prose descs and
  `iron.setup` gets no `keymaps` table at all. `iron_send_block`'s
  hardcoded `<leader>ef` feedkeys became `<leader>rs` in the same
  commit. The gS/gE opfunc pair's now-dead functions were removed from
  `ucw.keys.actions` with D1.
- **D9**: a `cond = false` plugin is dropped from
  `lazy.core.config.plugins` entirely (indexing it errors); the embedded
  census asserts absence via both spellings plus `package.loaded`.
- **Leftover, observed not changed**: rustaceanvim still binds
  buffer-local `<leader>a` (grouped code actions) in Rust buffers. It
  predates this phase and only exists per-buffer, but it sits on the
  letter §3 reserves for AI integration — resolve it when that goal
  lands (candidate: fold into `<leader>ca` as a buffer-local override).
