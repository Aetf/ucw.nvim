# Phase 4 design: folding, commenting, diagnostic rendering

Status: **revision 5 — implemented, reviewed twice, corrected.**

Revision 4 folds in `phase4-acceptance-review.md`: one confirmed regression in
the provider selector (§3.3 step 4 / §7), the two undeclared behaviour changes
it turned up (now S2 and S3 in §4), and the two verification-plan items that
r3 never reported on (§6a).

Revision 5 folds in that review's §5, which reviewed the r4 fixes themselves
and found one more (G1): the same escaping-`providers[2]` exception as r4's,
reached through `buftype` instead of a missing fold query, and firing on every
`K` — see §3.3 step 4 and §7. The lesson is in §7: r4 fixed *a case* of that
exception rather than *the class*, so the second occurrence was still open with
a full green suite.

Revision 2 recorded the three decisions taken after reviewing r1 (keep
`nvim-ufo`; core `gc`; keep `vim-fold-cycle`), and answered two questions r1
had left open: what else can actually be unified while keeping ufo (§3.3), and
the concrete mechanism behind the `InsertNoFold` / manual-fold contradiction
(§1.2). Answering the first turned up the phase's biggest practical win —
**ufo had never been using its treesitter provider here** (§1.3).

Revision 3 records the S1 decision (§4), the as-built numbers (§6), and what
verification actually found (§6a).

Section 1 describes the config *before* this phase and is left in the past
tense on purpose: it is the evidence the design rests on.

Goal 2 of the modernization ("clean up workarounds"), goal 3 ("reduce tech
islands"), and goal 4 ("swap in modern replacements"), applied to the three
clusters the plan file grouped under "Folding & syntax modernization":
folding (`treesitter.lua` / `ufo.lua` / `options.lua` / `vim-fold-cycle`),
commenting (`Comment.nvim` + `nvim-ts-context-commentstring`), and the
diagnostic renderer (`lsp_lines.nvim`).

Everything marked *measured* below was produced on this machine, on Neovim
0.12.3, against the real config via `scripts/tui-drive.sh` — not read off a
README and not inferred from a grep. Phase 3 cost two rounds of rework by
trusting static reading; this document tries not to repeat that.

---

## 0. The plan file's Phase 4 is partly stale

The plan was written before Phase 1 landed. Four of its claims, re-checked:

| Plan file says | Reality |
|---|---|
| Replace `nvim_treesitter#foldexpr()` with the native `foldexpr`, and delete the `BufEnter/BufAdd/…` "No folds found" workaround block | **Already done in Phase 1.** `treesitter.lua:108-109` already sets `v:lua.vim.treesitter.foldexpr()`; the workaround autocmd block no longer exists. Nothing left to do here. |
| Native `gc`/`gcc` covers embedded-language commentstrings | **True, measured** (§2.1). |
| `lsp_lines.nvim`'s "rendering is already 100% native `vim.diagnostic.config{virtual_lines=…}`" — so just inline the toggle | **False.** Measured: `vim.diagnostic.handlers.virtual_lines.show` resolves to `lsp_lines.nvim/lua/lsp_lines/init.lua`. The plugin *replaces* the core handler; the config table currently in effect uses the plugin's own key name. The swap is still small, but it is a swap, not a no-op (§2.3, §3.2). |
| Keep `nvim-ufo`: core has "only absorbed the underlying *provider* primitives (`vim.treesitter.foldexpr()`, experimental `vim.lsp.buf.foldexpr()`)" | **The premise is out of date**, though the conclusion survives. There is no `vim.lsp.buf.foldexpr`; it is `vim.lsp.foldexpr()`, and together with `vim.lsp.foldtext()` it is public, documented, and shipped with a worked "treesitter by default, LSP when the server supports it" recipe in `:h vim.lsp.foldexpr()`. Decision taken: **keep ufo** for the fold preview + fold-text line count, and unify around it instead (§3.3). |

---

## 1. What is actually running today

### 1.1 Fold state, measured

Real TUI, `lua/ucw/lsp/vscode.lua` open, `lua_ls` attached:

```
foldmethod = "manual"                              -- set by ufo, per window
foldexpr   = "v:lua.vim.treesitter.foldexpr()"     -- inert: fdm is manual
foldlevel  = 99                                    -- ufo, not the 1 in options.lua
foldtext   = "v:lua.require'ufo.main'.foldtext()"
foldcolumn = "1"
```

Fold policy is currently written in **three files that partly cancel each
other out**:

| Where | Sets | Actually in effect? |
|---|---|---|
| `options.lua:49,51,53` | `foldcolumn=1`, `foldlevel=1`, `foldminlines=3` | `foldcolumn`/`foldminlines` yes. `foldlevel=1` **no** — ufo overwrites it with 99 in the full UI; it only survives in firenvim/vscode. |
| `options.lua:55-62` | `BufWinEnter` → `normal! zv` | Yes, but a no-op while `foldlevel=99`. |
| `options.lua:63-81` | `InsertEnter` saves `foldmethod` and forces `manual`; `InsertLeave` restores + `zv` | **No-op in the full UI**, measured: entering insert mode gives `w:oldfdm == "manual"`, i.e. it "saves" ufo's manual and sets manual. Only live in firenvim/vscode. |
| `treesitter.lua:108-109` | `foldmethod=expr`, `foldexpr=treesitter` | **Overridden per window by ufo** (`ufo/fold/driver.lua:109` does `wo.foldmethod = 'manual'`). Only live in firenvim/vscode. |
| `ufo.lua:41-46,61-77` | `foldlevel/foldlevelstart=99`, `zR`/`zM` remaps, `foldingRange` capability, fold virt-text handler | Yes, in the full UI (`cond = is_full_ui`). |

So there are effectively **two different folding configurations** — ufo's in
the TUI/GUI and treesitter's in the embedded contexts — and the file each
setting lives in does not tell you which one it belongs to.

Two more fold-adjacent pieces:

* `vim-fold-cycle` (`fold-cycle.lua`): maps `<CR>` and `<BS>` in normal mode
  (`nmap <unique>`, via `g:fold_cycle_default_mapping`). Measured working:
  `<CR>` on a closed fold opens it, `<BS>` closes it again. Upstream's last
  commit is **2020-05-11**.
* `keys/actions.lua:108-118` — `K` is `hoverK`: try `ufo.peekFoldedLinesUnderCursor()`
  first, fall back to `vim.lsp.buf.hover()`. This is the one place ufo's UI
  layer is wired into a keymap.

### 1.2 Why ufo forces `foldlevel=99`, and why `InsertNoFold` is dead

Both halves of this were unclear in r1, so here is the actual mechanism, from
ufo's source plus measurement.

**ufo does not use `foldexpr` at all.** It requests fold *ranges*
asynchronously from a provider, then materialises them as **manual** folds.
`ufo/fold/driver.lua:135-152` (non-FFI path; `:109-118` is the FFI equivalent)
does, on every update:

```
level = wo.foldlevel        -- save
norm! zE                    -- erase every fold in the window
<n>,<m>:fold                -- recreate each range as a manual fold
setl foldmethod=manual
setl foldenable
setl foldlevel=<level>      -- restore
```

Vim's rule is that assigning `'foldlevel'` closes every fold deeper than that
level. So each of ufo's fold updates ends with "close everything deeper than
`foldlevel`" — and ufo updates often (on text change, and notably around
`InsertLeave`). With `foldlevel=1`, that means your folds slam shut while you
work. `foldlevel=99` is therefore **not a workaround bolted on the side; it is
a structural requirement of the manual-fold model** (this is upstream issue
\#7, already cited in `ufo.lua:37-40`). Keeping ufo means keeping it.

**Now `InsertNoFold`** (`options.lua:63-81`). It was written for the
pre-ufo world, where `foldmethod=expr`: there, folds are recomputed by Vim on
every buffer change, so typing inside a fold can reshape folds under the
cursor and jump the view. Forcing `foldmethod=manual` for the duration of
insert mode freezes fold computation — a legitimate trick *for expr folds*.

Under ufo, `foldmethod` is **already** `manual`. Measured on entering insert
mode in a real TUI: `w:oldfdm == "manual"`, i.e. the autocmd saves `manual`
and sets `manual`. It is an identity operation. And it cannot protect against
anything, because what recomputes folds now is not `foldexpr` (Vim does not
evaluate one — `foldmethod` is manual) but ufo's own async request plus the
`zE` + re-`:fold` cycle above, which `foldmethod` has no influence over.

So in the full UI the autocmd is dead code; its only live effect is the
`normal! zv` on `InsertLeave`, which with `foldlevel=99` only matters for
folds you closed by hand. In firenvim/vscode (where `treesitter.lua`'s
`foldmethod=expr` does survive, §1.1) the original rationale still applies.

One more reason to remove rather than leave it: `w:oldfdm` is window-local
state written before ufo attaches and read after. A window that enters insert
mode with `foldmethod=expr` (pre-attach) and leaves it after ufo took over
would restore `expr` onto a window whose folds ufo owns as manual. I have
*not* reproduced this — the attach window is small — so it is listed as a
hazard of the pattern, not as an observed bug.

### 1.3 ufo has never used its treesitter provider here

`ufo.lua` does not set `provider_selector`, and ufo's default is hard-coded in
`ufo/fold/manager.lua:105`:

```lua
fb.providers = {'lsp', 'indent'}
```

Measured at runtime, real config:

| buffer | providers | selected |
|---|---|---|
| `lua/ucw/lsp/vscode.lua` (lua_ls attached) | `{'lsp','indent'}` | `lsp` |
| a `.vim` file (no server configured) | `{'lsp','indent'}` | `indent` |

`requestFoldingRange` only ever consults `providers[1]` and `providers[2]`, so
`treesitter` is unreachable with the default. Every filetype without an LSP
server — which is most of them, given the nine servers in `lsp/servers.lua` —
has been getting **indent** folds, while the embedded contexts
(firenvim/vscode) get **treesitter** folds from `vim.treesitter.foldexpr()`.
Two different fold semantics, neither one chosen.

The difference is not academic. Same 11-line `.vim` file, fold level per line:

```
ufo / indent provider    1 1 1 1 1 0   0 0 0 0 0
vim.treesitter.foldexpr  1 2 2 2 2 1   0 1 1 1 1
                         └ function 1 ┘ ↑ └ fn 2 ┘
```

Indent produced a single flat fold over the first function, no nesting for the
`if` block inside it, and **no fold at all for the second function**.
Treesitter got all three right. This is the largest concrete improvement
available in this phase, and it is one line of config (§3.3).

### 1.4 Commenting, measured

`Comment.nvim` (`lazy = false`) + `nvim-ts-context-commentstring` as a
dependency, plus one extra mapping (`<c-/>` in GUI / `<c-_>` in the terminal →
`gcc`). Upstream `Comment.nvim`'s last commit is **2024-06-09**.

The only non-default option is `ignore = '^$'` (do not comment blank lines).
Measured on a markdown buffer, visual-selecting a blank line, a prose line and
another blank line:

```
Comment.nvim  →  "", "<!-- Some prose here. -->", ""
core gc       →  "<!---->", "<!-- Some prose here. -->", "<!---->"
```

That is the one real behavioral difference (§3.1).

### 1.5 Diagnostic rendering, measured

```lua
vim.diagnostic.handlers.virtual_lines.show
  --> @…/lazy/lsp_lines.nvim/lua/lsp_lines/init.lua
vim.diagnostic.config().virtual_lines
  --> { only_current_line = true }
```

`lsp_lines.setup()` overwrites the core handler, so the rendering on screen is
the plugin's. `only_current_line` is the plugin's key name; core's equivalent
is `current_line`. The `<leader>lp` toggle in `lsp_lines.lua:1-11` writes
`only_current_line`, which the core handler would silently ignore — a latent
bug the moment the plugin goes away.

Upstream's last commit is **2024-12-10**.

---

## 2. What Neovim 0.12 provides, measured

### 2.1 `gc` is already injection-aware

`$VIMRUNTIME/lua/vim/_comment.lua` resolves `commentstring` from the deepest
`LanguageTree` covering the cursor, and from `bo.commentstring` capture
metadata. Measured, markdown buffer with a ```` ```lua ```` fence:

```
cursor inside the fence, core toggle_lines →  "-- local x = 1"
buffer commentstring                       →  "<!-- %s -->"
```

That is exactly what `nvim-ts-context-commentstring` exists to provide.

Core mappings (`nvim --clean`): `gc` (n/x operator), `gcc` (line, **honours a
count** — `3gcc` comments three lines, measured), `gc` (o, comment textobject).
Core does **not** provide `Comment.nvim`'s `gb`/`gbc` (blockwise) or
`gco`/`gcO`/`gcA` (open a comment line below/above/at end of line).

### 2.2 Native folding is a complete story now

* `vim.treesitter.foldexpr()` — incremental, async, already used here.
* `vim.lsp.foldexpr()` and `vim.lsp.foldtext()` — public and documented
  (`:h vim.lsp.foldexpr()`), including the recipe of defaulting to treesitter
  and upgrading a window to LSP folds in an `LspAttach` autocmd when the
  client supports `textDocument/foldingRange`. `lua_ls` advertises
  `foldingRangeProvider = true` (measured), so this path is real here.
* `foldtext = ''` renders a closed fold as its first line with **full syntax
  highlighting** and no `+--- N lines ---` clutter. Measured against the same
  file ufo was folding:

  ```
  native (foldtext='')   31 local function normalize_keys(obj)
  ufo                  + 10 local function normalize_keys(obj)          9
  ```

  Native has no line-count suffix; `'foldtext'` returns a plain string, so
  ufo's per-chunk highlighted virt-text handler has no native equivalent.

What native still does **not** have: ufo's fold *preview popup*
(`peekFoldedLinesUnderCursor`, wired to `K`), and multi-provider fallback
orchestration (the `LspAttach` recipe above is ~8 lines and covers the
lsp→treesitter case, but there is no indent fallback).

### 2.3 The core `virtual_lines` handler renders the same thing

Same two synthetic diagnostics (one 2-line ERROR, one WARN, same line), same
`virtual_text` config, side-by-side captures:

```
lsp_lines.nvim                          core, virtual_lines={current_line=true}
  22       ●● undefined global `F`…       22      ●● unused local
       │└──── unused local                      │└──── unused local
       └──── undefined global `F`               └──── undefined global `F`
             second line of the message               second line of the message
```

Identical box-drawing, identical multi-line message indentation. (The
`virtual_text` line differs only because the two instances picked a different
diagnostic to show first; that is the pre-existing `virtual_text` config, not
the handler.) Core additionally supports `current_line`, `format`, and
per-severity highlights.

### 2.4 Not a problem: rainbow-delimiters

Checked because it rides on `treesitter.lua`'s dependency list and the plan
groups "syntax" into this phase: `rainbow-delimiters.is_enabled(buf)` is true
and nested parens do render in different colors under the rewritten
nvim-treesitter API. **No change proposed.**

---

## 3. Proposal

### 3.1 Commenting: delete both plugins, use core `gc`

Delete `lua/ucw/plugins/comment.lua` (which also removes the
`nvim-ts-context-commentstring` dependency). Keep only the terminal/GUI
`<c-/>`/`<c-_>` → `gcc` mapping, moved into `lua/ucw/keys.lua` next to the
other global keymaps.

Rationale: the reason `Comment.nvim` was chosen (an operator plus TS-aware
commentstring) is now in core, verified by measurement rather than by release
notes. `Comment.nvim` has been dormant for ~2 years. Two plugins, ~0.85 ms of
startup, and one monkey-patched `pre_hook` bridge go away.

**Costs, accepted under D2:**

1. Blank lines get commented (`<!---->`), where `ignore = '^$'` skips them
   today. Core has no equivalent option; there is no small shim, since the
   ignore test happens inside core's operator. If this turns out to be
   irritating in daily use, the exit is `mini.comment` (already vendored via
   `mini.nvim`, has `options.ignore_blank_line`) — worth remembering rather
   than re-deriving.
2. `gb`/`gbc` (blockwise comment) and `gco`/`gcO`/`gcA` (open a comment line
   below/above/at end of line) disappear. Nothing in this config binds them,
   but they were reachable and now will not be.

Kept: `gcc` still honours counts (`3gcc`, measured), `gc` still works as an
operator and as a textobject, and the injection-aware commentstring is
unchanged (§2.1).

### 3.2 Diagnostics: delete `lsp_lines.nvim`

Delete `lua/ucw/plugins/lsp_lines.lua`. Move the two things it owned into code
that already exists:

* the default — `virtual_lines = { current_line = true }` — into
  `lua/ucw/options.lua`'s diagnostic config (or wherever `virtual_text` is
  configured today, so both live together);
* the `<leader>lp` toggle — into `lua/ucw/keys/actions.lua` as a ~6-line
  function, **using `current_line`**, fixing the latent key-name bug in §1.5.

Rendering parity is measured (§2.3), so this is low risk. One plugin and
~0.6 ms go away. No decision needed unless you disagree with the parity call —
I can put both side by side in a live TUI before committing.

### 3.3 Folding: ufo becomes the single owner (D1 = keep ufo)

Fold policy ends up in **one** place instead of three files that overwrite
each other, and ufo keeps the two things core has no answer for: the fold
preview popup on `K` and the `  N` line count in fold text.

Concretely:

1. **`treesitter.lua` stops touching folds.** Delete `foldmethod`/`foldexpr`
   (lines 108-109). That spec goes back to being exactly what its name says:
   highlighting, indent, parser install. This is the "second source of
   fold-state fighting" the plan file wanted gone.
2. **`ufo.lua` owns fold policy for the full UI** — `foldlevel`,
   `foldlevelstart`, `zR`/`zM`, `foldtext`, capability advertisement, and (new)
   the provider selection below. The `foldlevel = 99` line gets the §1.2
   explanation as a comment so the next reader does not "clean it up".
3. **The embedded contexts (firenvim/vscode) get an explicit fold block** in
   `options.lua`, guarded by `not require('ucw.targets').is_full_ui()`:
   `foldmethod=expr` + `foldexpr=v:lua.vim.treesitter.foldexpr()` + the
   `foldlevel` that context should have. Today those contexts are served by a
   line in `treesitter.lua` that only reaches them because ufo happens not to
   load — accident, not design. After this it is a stated branch: *ufo here,
   native there.*
4. **`provider_selector` switches the fallback from `indent` to
   `treesitter`** (§1.3 — the real win):

   ```lua
   provider_selector = function(_, filetype, _)
     -- ufo only ever consults providers[1] and providers[2]
     return has_parser(filetype) and { 'lsp', 'treesitter' } or { 'lsp', 'indent' }
   end
   ```

   This is also what unifies the two halves of the config: with it, a buffer
   without an LSP server folds by treesitter in the TUI *and* in
   firenvim/vscode — same structure, same fold boundaries, two different
   engines producing them. Without it they disagree (§1.3's 11-line example).

   `has_parser` should be a real check (`vim.treesitter.language.add` /
   `vim.treesitter.get_parser` in a `pcall`) rather than a hard-coded list, so
   it stays correct as parsers get installed — note this machine currently has
   only the 7 bundled parsers, so a naive filetype list would be wrong here in
   a way that would not show up until the `tree-sitter` CLI exists.

   **r4 correction — this is half a check.** A loadable parser is not
   sufficient: ufo's treesitter provider raises `UfoFallbackException` when the
   language has no `folds` query, and since it sits in `providers[2]` there is
   nowhere left to fall back to — `ufo/provider/init.lua` calls the fallback
   *inside* the main provider's rejection handler, unguarded, so the exception
   escapes the promise chain. The buffer gets no folds at all plus an
   `UnhandledPromiseRejection` in `:messages`. `has_parser` has to test
   `#vim.treesitter.query.get_files(lang, 'folds') > 0` as well. See §7.

   **r5 correction — the third parameter is load-bearing too.** That same
   exception escapes for `buftype == 'nofile'`, where *both* providers raise it
   (`provider/treesitter.lua:177`, `provider/lsp/init.lua:48`), and the selector
   was discarding `buftype` as `_`. ufo attaches on `BufWinEnter`, floating
   windows included, so this fired on every `K`: the hover float is `nofile`
   with `filetype=markdown`, which has both a parser and a fold query. The
   selector now gates on `buftype` first — only `''` and `'acwrite'` reach
   either provider's real code path, so everything else gets `indent`, which is
   what the pre-Phase-4 default gave them anyway. See §7.
5. **Delete the `InsertNoFold` autocmd** (`options.lua:63-81`) — §1.2: it is
   an identity operation under ufo and it cannot influence what ufo does. The
   `normal! zv` on `InsertLeave` can be kept as a one-line autocmd if you want
   it; the `foldmethod` juggling goes.
6. **`BufWinEnter` → `zv`** (`options.lua:55-62`) can stay; it costs nothing
   and is meaningful the moment `foldlevel` is not 99 (i.e. in the embedded
   contexts after step 3).

Not changed: `zR`/`zM` remaps (required by the manual-fold model, §1.2),
`hoverK`, `foldcolumn`, `foldminlines`, `open_fold_hl_timeout`, the
`fold_virt_text_handler`, and the `vim.lsp.config('*')` `foldingRange`
capability from Phase 3.

**Open sub-question (S1):** should `foldlevel` in the embedded contexts be
`1` (what `options.lua` says today and what those contexts actually get) or
`99` (what the TUI gets)? Right now the two differ purely by accident. I lean
`99` for consistency — "files open fully expanded everywhere" — but this is
the one place where step 3 can silently change firenvim/vscode behavior, so
it should be a choice.

### 3.4 `vim-fold-cycle`: keep (D3 = keep)

Unmaintained since 2020, but small (0.17 ms) and measured working against
ufo's manual folds. It uses only stable Vim fold APIs, so "unmaintained" here
mostly means "finished". No change — but it does need one new check: it has
never been verified against the **expr** folds the embedded contexts use, and
step 3 above makes that path explicit for the first time.

---

## 4. Decisions

Taken (r2):

* **D1 — fold engine: keep `nvim-ufo`**, and unify around it (§3.3). Native
  folding is now a complete story (§2.2), but it would cost the fold preview
  popup on `K` and the line count in fold text, both of which are deliberate
  choices in this config.
* **D2 — commenting: core `gc`**, delete `Comment.nvim` and
  `nvim-ts-context-commentstring` (§3.1). Accepted costs: blank lines get
  commented, and `gb`/`gbc`/`gco`/`gcO`/`gcA` go away.
* **D3 — `vim-fold-cycle`: keep** (§3.4).

Settled without needing a decision: `lsp_lines.nvim` is deleted (§3.2, parity
measured), and `treesitter.lua` stops setting fold options (§3.3 step 1).

* **S1 — `foldlevel` in firenvim/vscode: `1`.** Not "consistency with the
  TUI" — those contexts have a cramped layout (a browser textarea, a VSCode
  editor pane), so opening files mostly folded is the useful default there.
  This is the first time that value is a stated choice rather than a line in
  `options.lua` that survived only where ufo did not load.

Taken in r4, both flagged by the acceptance review as changes that happened
without being decided:

* **S2 — `virtual_lines` in firenvim/vscode: off.** `lsp_lines.nvim` was
  `cond = is_full_ui`; moving its default into `ucw.options` (§3.2) quietly
  widened it to every context. Same reasoning as S1: those layouts cannot
  spare two or three lines under the cursor. The branch now sits next to the
  fold branch, in the same `is_full_ui()` shape.
* **S3 — `<leader>lp` modes: normal + visual.** The deleted spec bound it with
  `vim.keymap.set('', …)` — normal, visual/select and operator-pending. The
  which-key entry that replaced it defaulted to normal only. Operator-pending
  is meaningless for a toggle; the other two are restored.

Nothing open.

## 5. Verification plan

Static checks and green tests both lied in Phase 3; the plan is to drive a
real TUI for each claim.

1. **Provider switch** (the change most likely to regress silently): for each
   of a Lua file (LSP), a `.vim` file (parser, no LSP) and a file with neither
   parser nor LSP, assert ufo's `selectedProvider` and the resulting
   `foldlevel()` vector — the exact measurement in §1.3, re-run after the
   change. Expected: `lsp`, `treesitter`, `indent`.
2. **Folds, real TUI** (`scripts/tui-drive.sh`): `zc`/`zo`/`zR`/`zM`,
   `foldclosed()` at known lines, screenshot of a closed fold so the `  N`
   fold text is confirmed still rendering.
3. **`vim-fold-cycle` on expr folds**: `<CR>`/`<BS>` in a firenvim/vscode-shaped
   session, where folds are native rather than ufo's manual ones. Never been
   tested there (§3.4).
4. **Insert-mode behavior with `InsertNoFold` gone**: type inside a fold in
   both the TUI (ufo/manual) and the native-fold path, confirm no cursor jump
   and no fold slam-shut. The native path is the one where the original
   rationale still applies, so it is the one that can actually regress.
5. **Embedded contexts**: assert the resulting `foldmethod`/`foldexpr`/
   `foldlevel` under `is_full_ui() == false`. These never appear in the TUI
   loop, so a `cond`-shaped mistake here is invisible — this is the same shape
   as the Phase 3 bug where rust buffers had no keymaps because the tests only
   ever exercised the main path.
6. **Commenting**, real TUI: `gcc`, `3gcc`, visual `gc`, `gc` textobject, and
   the `<c-_>` mapping — in Lua, and in a markdown file with a fenced Lua
   block (the injection case that justified deleting
   `nvim-ts-context-commentstring`).
7. **Diagnostics**: toggle `<leader>lp` both ways with a real LSP diagnostic
   on screen, screenshot both states, confirm `current_line` actually takes
   effect (the key-name bug in §1.5 is exactly the kind that passes a "it
   didn't error" check).
8. `just unit` + `just int` + startup measurement for the as-built numbers.

New tests to add: `tests/test_fold.lua` (provider selection per buffer kind,
fold levels, rendered fold text, and the non-full-UI branch) and
`tests/test_comment.lua` (injection case, count case). Behavior/screenshot
tests, not "does the module load" tests.

---

## 6. Numbers

Baseline, measured before the change:

```
plugins:            53 specs, 44 loaded at startup
lazy startuptime:   107 ms (real TUI, cold-ish)
headless startup:   54 ms warm / 72 ms first run
load time of the plugins in scope:
  nvim-ufo          1.26 ms      Comment.nvim                  0.57 ms
  promise-async     0.11 ms      nvim-ts-context-commentstring 0.28 ms
  lsp_lines.nvim    0.60 ms      vim-fold-cycle                0.17 ms
```

As built:

```
plugins:            50 specs, 41 loaded at startup   (-3 / -3)
lazy startuptime:   105 ms                            (-2 ms)
headless startup:   49 ms warm / 62 ms first run      (-5 ms / -10 ms)
```

`Comment.nvim`, `nvim-ts-context-commentstring` and `lsp_lines.nvim` are gone;
`nvim-ufo`, `promise-async` and `vim-fold-cycle` stay. The milliseconds are not
the point of this phase - the fold fight and the indent-vs-treesitter
divergence are - but they are recorded rather than claimed.

---

## 6a. Verification results (as built)

All measured in a real TUI or a real headless boot, not inferred:

| Check | Result |
|---|---|
| Provider on a Lua buffer (lua_ls attached) | `{'lsp','treesitter'}`, selected **lsp** |
| Provider on a `.vim` buffer (parser, no server) | selected **treesitter**, levels `1 2 2 2 2 1 0 1 1 1 1` (was `1 1 1 1 1 0 0 0 0 0 0` under indent) |
| Provider on a `.conf` buffer (no parser, no server) | `{'lsp','indent'}`, selected **indent**, folds still produced |
| ufo fold text | `+ 10 local function normalize_keys(obj)  9` — line count intact |
| `zM` / `zR` / `<CR>` / `<BS>` (vim-fold-cycle) | all still work on ufo's manual folds |
| `K` on a closed fold | ufo peek float, 16 lines of the folded body |
| Global `'foldexpr'` in the full UI | `0` (Vim's default) — treesitter.lua no longer leaks one |
| firenvim target (`g:started_by_firenvim`) | ufo **not** loaded, `foldmethod=expr`, `foldexpr=v:lua.vim.treesitter.foldexpr()`, `foldlevel=1`, nested fold closed on open |
| Insert mode on expr folds, `InsertNoFold` removed | `foldmethod` stays `expr`, `w:oldfdm` never set, cursor and viewport unchanged across `A…<Esc>` |
| Core `gc` in markdown | `--` inside a ```` ```lua ```` fence, `<!-- -->` outside, `3gcc` honours the count, blank line becomes `<!---->` |
| `<c-_>` → `gcc` | mapped; `gcc` resolves to `vim/_core/defaults`, not a plugin |
| `virtual_lines` handler | `$VIMRUNTIME/lua/vim/diagnostic.lua`, config `{ current_line = true }` |
| `<leader>lp` | toggles off and back on, rendering matches the old plugin |
| `just unit` / `just int` | 28 + 53 cases, 0 failures |

Added in r4, after the acceptance review:

| Check | Result |
|---|---|
| Provider on a buffer whose parser has **no fold query** (`ft=help`, `buftype=''` — `vimdoc` is bundled, ships no `folds.scm`) | **was broken**: `{'lsp','treesitter'}`, no provider settled, 0 folds, `UnhandledPromiseRejection` in `:messages`. Fixed: `{'lsp','indent'}`, selected **indent**, 5/21 lines folded |
| Provider with a server advertising `foldingRangeProvider` (in-process fake) | selected **lsp**, and the ranges applied are the server's |
| ufo fold text on screen, real TUI | the `  5` line count renders on the closed fold line |
| `K` on a closed fold | ufo's peek float opens, through the `hoverK` mapping |
| `<CR>` / `<BS>` (vim-fold-cycle) on **expr** folds — §5 item 3, never run in r3 | works: `<CR>` opens the nested fold, again cycles round and closes the outer one, `<BS>` reverses it. D3 holds on both fold engines |
| `gc` as a **textobject** — §5 item 6, never run in r3 | `dgc` deletes exactly the comment block; `gcap` comments a paragraph |
| `virtual_lines` in a firenvim boot (S2) | `false`, with `foldmethod=expr` / `foldlevel=1` unchanged |
| `<leader>lp` modes (S3) | bound in `n` and `v` |

New tests: `tests/test_fold.lua` (9 cases — provider selection per buffer kind
including the missing-fold-query case and the LSP case, ufo's ownership of the
fold options, the fold text and peek popup on screen, no global `foldexpr`, and
the firenvim/vscode branch), `tests/test_comment.lua` (6 cases — injected
commentstring, buffer commentstring, count, visual operator, the `<c-_>`
shortcut, and that neither comment plugin is installed any more) and
`tests/test_diagnostics.lua` (5 cases — the default, that the handler is core's,
S2, the toggle in both directions, and S3).

Each of the three r4 fixes was checked the other way round as well: with the fix
reverted, exactly its own test fails and nothing else does. r3's tests passed
either way, which is how the provider bug shipped.

Two things worth recording from building it:

* **`vim.treesitter.language.add()` returns `nil, err` rather than raising**, so
  a `pcall` around it always succeeds. `has_parser` has to test the return
  value. A first version of the test asserted via `not pcall(...)` and passed
  vacuously in the wrong direction.
* **`...` anywhere but last in a Lua argument list is truncated to one value**,
  which is why the test helpers wrap `child.lua_get` bodies in a function
  rather than splicing `...` into an api call.

---

## 7. Risks

* **The provider switch changes folds everywhere at once.** Every buffer
  without an LSP server gets different fold boundaries than it had yesterday
  (§1.3). That is the intent, but it is a large, immediately visible change —
  more so than anything else in this phase. If treesitter folds turn out worse
  for some filetype, `provider_selector` is the single knob to special-case
  it.
* **`has_parser` is easy to get wrong on this machine.** Only the 7 bundled
  parsers exist here (no `tree-sitter` CLI), so a check that is really testing
  "is this filetype in nvim-treesitter's list" would claim treesitter folds for
  buffers that have no parser, and ufo would fall through to nothing rather
  than to indent. Verify with a filetype that has an entry in
  `ensure_installed` but no compiled parser — that is most of them here.

  **This risk was right about the direction and wrong about the failure mode,
  and it happened.** The check written from it tested the parser and shipped;
  what actually bites is a missing *fold query*. `vimdoc` is bundled with
  Neovim and has no `folds.scm`, so `has_parser('help')` was true on a machine
  with no `tree-sitter` CLI at all, and editing any plugin's `doc/*.txt` lost
  its folds. Once parsers are installed it widens: of the 47 languages in
  `ensure_installed`, `dockerfile`, `json5`, `llvm`, `pug`, `rst`, `vimdoc` and
  `openscad` ship a parser and no fold query. Fixed in r4; the lesson is that
  "does the provider *work* here" is the question, and a parser was only a
  proxy for it.

  **And it happened a second time, because r4 fixed the case instead of the
  class.** Nothing raises `UfoFallbackException` *only* over a missing fold
  query: `buftype == 'nofile'` raises it too, from both providers, and the
  selector was ignoring `buftype` entirely. Since ufo attaches on
  `BufWinEnter` — floating windows included — the `nofile`, `filetype=markdown`
  hover float meant **every `K` printed a traceback**, which the r4 review had
  not thought to look for because it was hunting fold *content*, not noise.
  Fixed in r5 by gating on `buftype` before anything else. The general lesson,
  now twice: when a dependency's error escapes because of *where the call sits*
  (`providers[2]` has no catcher), enumerate every path that raises it — fixing
  one of them tells you nothing about the others, and the test suite stays green
  either way.
* **Fold state is window-local and order-dependent.** Moving settings between
  files changes *when* they run relative to plugin `config` functions. The
  embedded contexts are the blind spot; cover them with explicit assertions
  rather than by inspection.
* **`foldlevel` in the embedded contexts (S1)** silently becomes a decision
  the moment step 3 makes that branch explicit. Whichever way it goes, it
  should be a written choice, not a leftover.
* **Blank-line commenting is churn you cannot un-see**: from the first commit
  onward, every commented block in every file gets `--` on its blank lines.
  Reversible in config (`mini.comment`), not in diffs already made.
* **`InsertNoFold` removal is a behavior bet on the native path.** Under ufo
  it is provably inert (§1.2); under expr folds it was written for a real
  problem. Item 4 in §5 is the check that decides whether it can go for both
  paths or only for the ufo one.

---

## 8. Observed, out of scope

While probing, a `blink-cmp-menu` float was left on screen after driving an
`:lua …` command over the tui-drive control socket (buffer unmodified, mode
`n`, float never closed). It does not reproduce on a fresh session without
cmdline input, so it looks like a blink cmdline-completion menu that is not
torn down when the cmdline is driven over RPC. Noted here so it is not lost;
it belongs to the completion phase, not this one.
