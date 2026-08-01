# Phase 4 acceptance review

Reviewed: commit `6aac305` ("Phase 4: give folding one owner, and drop three
plugins for core equivalents") against `docs/design/phase4-folding-comments.md`
(r3) and the plan file's Phase 4 section.

**Resolved.** F1, F2, F3 and F5 are fixed in the follow-up commit; F4 and F6
were verification gaps and both pass. The design document is now at revision 4
and carries the outcomes. This file is left as the point-in-time record of what
the review found and how — deliberately not rewritten into the past tense.

**Verdict: do not accept as-is.** One confirmed regression (F1), two undeclared
behaviour changes (F2, F3), one verification-plan item that was never reported
(F4, now run — it passes), and a test-suite blind spot that lets F1 through
green (F5). Everything else in §6a of the design document re-measured true.

Same rule as the design doc: everything below marked *measured* was produced on
this machine, Neovim 0.12.3, against the real config — via `just all`,
`scripts/tui-drive.sh`, and a firenvim-shaped boot. Nothing here is inferred
from reading the diff.

---

## 1. Findings

| # | Finding | Kind | Severity |
|---|---|---|---|
| F1 | `has_parser` accepts a language with **no `folds` query**, and ufo has no third fallback → such buffers get **zero folds** plus an unhandled-promise traceback | regression, live today on `ft=help` | **blocker** |
| F2 | `<leader>lp` lost its visual/operator modes (`vim.keymap.set("")` → which-key's default `n`) | undeclared behaviour change | minor |
| F3 | `virtual_lines` is now on in firenvim/vscode; `lsp_lines.nvim` had `cond = is_full_ui` | undeclared behaviour change | minor, needs a decision |
| F4 | §5 verification item 3 (`vim-fold-cycle` on **expr** folds) never appears in §6a | verification gap | closed by this review — it passes |
| F5 | `tests/test_fold.lua` passes both with and without the F1 bug | test gap | medium |
| F6 | §5 item 6's `gc` **textobject** case is neither in §6a nor in `tests/test_comment.lua` | verification gap | closed by this review — it passes |

### F1 — treesitter is preferred for languages that have no fold query (blocker)

`ufo.lua:43-46`:

```lua
local function has_parser(filetype)
  local lang = vim.treesitter.language.get_lang(filetype)
  return lang ~= nil and vim.treesitter.language.add(lang) == true
end
```

This tests that a **parser** loads. ufo's treesitter provider needs a **`folds`
query** as well: `ufo/provider/treesitter.lua:186-190` raises
`UfoFallbackException` when no tree in the buffer has one. The design document
correctly established (§1.3, and `ufo/provider/init.lua:28-47`) that ufo only
consults `providers[1]` and `providers[2]` — but the consequence was not
followed through: **when `providers[2]` raises, there is nothing left to fall
back to.** `Provider:requestFoldingRange` calls `fallbackFunc(bufnr)` inside the
main provider's rejection handler, unguarded, so the exception escapes the whole
promise chain.

So `{'lsp','treesitter'}` on a language with a parser but no fold query is
strictly worse than the `{'lsp','indent'}` it replaced: no folds at all, where
indent folds used to be.

**Measured, real TUI, A/B on the same file** (a `.txt` file ending in
`vim:ft=help:` — i.e. any plugin's `doc/*.txt`, 21 lines, `buftype=''`):

```
selector                       providers              selected   lines in a fold
{'lsp','treesitter'} (as built) { "lsp", "treesitter" } nil                  0/21
{'lsp','indent'}     (before)   { "lsp", "indent" }     indent               5/21
```

The as-built run also prints, in `:messages`:

```
vim.schedule callback: UnhandledPromiseRejection with the reason:
...nvim-ufo/lua/ufo/provider/treesitter.lua:199: UfoFallbackException
```

**Live today.** `vimdoc` is one of the seven parsers bundled with Neovim, and
`$VIMRUNTIME/queries/vimdoc/` has no `folds.scm`. `has_parser('help')` is
therefore `true` on a machine with no `tree-sitter` CLI at all. (`:help` itself
is unaffected — `buftype=help` makes both providers bail before this point.
It is *editing* a help file that breaks.)

**Grows on the next `TSUpdate`.** nvim-treesitter installs its `folds.scm`
alongside each parser into `stdpath('data')/site/queries/<lang>/`. Of the 47
languages in `treesitter.lua`'s `ensure_installed`, these ship a parser and **no
fold query** (measured against `nvim-treesitter/runtime/queries/`):

```
dockerfile   json5   llvm   pug   rst   vimdoc   openscad (no query dir at all)
comment, jsdoc, regex — injection-only, not filetypes
```

So the moment the `tree-sitter` CLI is installed — an explicit intent in
`treesitter.lua` — Dockerfiles, reStructuredText and JSON5 lose folding too.

This directly contradicts the comment above `has_parser`: *"Claiming treesitter
folds for a language whose parser is missing would leave the buffer with no
folds at all, since ufo only consults two providers."* The hazard was identified;
the check just does not cover all of it.

**Fix (measured — applied, verified in a real TUI, then reverted):**

```lua
local function has_parser(filetype)
  local lang = vim.treesitter.language.get_lang(filetype)
  if lang == nil or vim.treesitter.language.add(lang) ~= true then
    return false
  end
  -- A parser is not enough: ufo's treesitter provider raises
  -- UfoFallbackException when no `folds` query exists, and providers[2] has
  -- nothing to fall back *to*.
  return #vim.treesitter.query.get_files(lang, 'folds') > 0
end
```

`vim.treesitter.query.get_files` is the same call ufo's provider uses. With it:

```
help       prov={ "lsp", "indent" }      sel=indent      in_fold= 5/21   (restored)
vim        prov={ "lsp", "treesitter" }  sel=treesitter  in_fold=10/11   (unchanged)
markdown   prov={ "lsp", "treesitter" }  sel=treesitter  in_fold=17/17   (unchanged)
lua        prov={ "lsp", "treesitter" }  sel=lsp         in_fold=54/195  (unchanged)
```

`just int` stays green (45/45) — see F5.

One conservatism worth stating rather than discovering later: ufo raises only
when *no* tree in the buffer has a fold query, so a host language without one
whose injections have one would still fold. The check above looks at the host
language only, and picks `indent` for that case.

### F2 — `<leader>lp` silently lost its non-normal modes

The deleted spec bound it with `vim.keymap.set("", "<leader>lp", toggle, …)` —
mode `""` is `:map`, i.e. normal + visual/select + operator-pending. The
replacement is a which-key entry with no `mode` field, which defaults to normal.

Measured, real TUI: `<leader>lp` resolves in `n` only.

Probably nobody toggles diagnostic rendering from visual mode, but it was not a
stated cost. Either add `mode = { 'n', 'v' }` or record it as accepted, the way
the `gb`/`gco` losses were recorded in §3.1.

### F3 — diagnostics rendering changed in the embedded contexts

`lsp_lines.nvim` was `cond = is_full_ui` **and** `event = 'LspAttach'`. Its
replacement is an unconditional `virtual_lines = { current_line = true }` in
`ucw.options`, so firenvim and vscode-neovim now render full diagnostic text
below the cursor line where they previously rendered none.

Measured in a firenvim-shaped boot (`g:started_by_firenvim = v:true`):

```
vim.diagnostic.config().virtual_lines  ->  { current_line = true }
<leader>lp                             ->  mapped (which-key has no cond)
```

This is the same shape as S1 (`foldlevel` in the embedded contexts), and it
deserves the same treatment: those layouts are cramped — a browser textarea
losing two or three lines under the cursor to a diagnostic box is a real cost —
so it should be a written choice, not a side effect of moving the setting from a
`cond`-ed plugin spec into global options. §3.2 said "move the default into
`options.lua`" without noting that this widens its scope.

### F4 — `vim-fold-cycle` on expr folds: never reported (now run, passes)

§3.4 flagged it explicitly: *"it has never been verified against the **expr**
folds the embedded contexts use, and step 3 above makes that path explicit for
the first time"*, and §5 made it verification item 3. §6a reports only
`<CR>`/`<BS>` "on ufo's manual folds" — the item was dropped, not answered.

Run here, firenvim-shaped boot on the 11-line vimscript fixture,
`foldclosed()` per line after each key:

```
on open      -1  2  2  2  2 -1 -1 -1 -1 -1 -1    nested fold closed (foldlevel=1)
<CR>         -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1    opens the nested fold
<CR>          1  1  1  1  1  1 -1 -1 -1 -1 -1    cycles round: closes the outer fold
<BS>         -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
<BS>         -1  2  2  2  2 -1 -1 -1 -1 -1 -1    back to the initial state
```

D3 (keep `vim-fold-cycle`) holds on both fold engines. The rest of the embedded
branch re-measured as §6a claims: `foldmethod=expr`,
`foldexpr=v:lua.vim.treesitter.foldexpr()`, `foldlevel=1`, ufo not loaded.

### F5 — the fold tests cannot see F1

`just all`: 73/73 green, both with the bug and with the F1 fix applied. The
suite asserts the two ends of the selector —

* parser + no LSP → `treesitter` (the `.vim` case), and
* no parser + no LSP → `indent` (the `.conf` case)

— and never the case in between: **parser present, fold query absent**. That is
precisely the branch F1 gets wrong, and it is one `eq` away:

```lua
-- ft=help -> lang vimdoc: a bundled parser, no folds.scm anywhere
T['provider selection']['falls back to indent when the parser has no fold query']
```

Two smaller gaps in the same file, both claimed measured in §6a but not pinned
by a test:

* the `lsp` provider case (a Lua buffer with `lua_ls`) — the most common path in
  daily use has no assertion at all;
* the fold text (`  N` line count) and the `K` peek popup — the two things D1
  cited as the *reason to keep ufo* are not covered, so a future ufo bump can
  break them silently. `tests/test_tui_screenshot.lua` already shows the
  machinery for this.

The `embedded contexts` cases deserve a note too: they assert `ucw.options` in
isolation (`child.restart` + `require('ucw.options')`), which proves the branch
is written correctly but not that a firenvim boot ends up there — no assertion
that ufo is absent, no fold levels. The comment explains why a full boot cannot
be used, which is fair; the residual risk is worth naming in the file rather
than left implicit, since §5 item 5 called this exact blind spot out as
"the same shape as the Phase 3 bug".

### F6 — `gc` as a textobject: not verified (now run, passes)

§5 item 6 lists "`gc` textobject"; §6a does not report it and
`tests/test_comment.lua` covers `gcc`, `3gcc`, visual `gc` and `<c-_>`, but not
the textobject. Measured in a real TUI on a Lua buffer with a two-line comment
block: `dgc` deletes exactly the block, and `gcap` comments a paragraph. Core
provides both.

---

## 2. Re-measured: claims that hold

Every row of §6a that I could re-run, re-run. All confirmed.

| Claim (§6a / commit message) | Re-measured |
|---|---|
| Provider on a Lua buffer (lua_ls attached) | `{ "lsp", "treesitter" }`, selected **lsp**, 54/195 lines in folds |
| Provider on a `.vim` buffer (parser, no server) | selected **treesitter**, levels `1 2 2 2 2 1 0 1 1 1 1` |
| Provider on a no-parser/no-server buffer | `{ "lsp", "indent" }` |
| Markdown, which used to get **nothing** from the indent provider | now 17/17 lines in folds via treesitter — the phase's biggest real win, and it is bigger than the doc claims |
| Global `'foldexpr'` in the full UI | `0` — `treesitter.lua` leaks nothing |
| firenvim target | ufo not loaded; `foldmethod=expr`, treesitter `foldexpr`, `foldlevel=1`, nested fold closed on open |
| Core `gc` injection-awareness, count, blank lines | as documented (`tests/test_comment.lua`, re-run green) |
| `<c-_>` → `gcc`, resolving to core | mapped, in both the full UI and the firenvim boot |
| `virtual_lines` handler is core's | `/usr/share/nvim/runtime/lua/vim/diagnostic.lua` |
| `<leader>lp` toggles both ways | `{current_line=true}` → `false` → `{current_line=true}`, and the diagnostic box measurably leaves and returns to the screen |
| 50 specs, 41 loaded | exactly, via `lazy.core.config` |
| headless startup 49 ms warm | 49.5 / 53.1 / 56.5 ms over three runs |
| `just unit` + `just int` | 28 + 45 = 73 cases, 0 failures |
| No dangling references to the three deleted plugins | none outside comments and docs; `lazy-lock.json` clean |
| §8's stray `blink-cmp-menu` float after RPC-driven cmdline | still reproduces; correctly parked for the completion phase |

The two Lua-level notes in §6a (`language.add` returns `nil, err`; `...` in a
non-final argument position) are both correct and both still load-bearing.

`au.group` accepting `{ 'BufWinEnter', 'InsertLeave' }` was worth checking since
`lua/au.lua` is hand-rolled: it concatenates event tables, so the merged
`UnfoldCursorLine` group is fine.

---

## 3. Recommended actions before accepting

1. **F1** — apply the `has_parser` fix, and add the missing test
   (parser + no fold query → `indent`). Non-optional: it is a live regression on
   `ft=help` today and a growing one after the next parser install.
2. **F5** — add the `lsp`-provider case and a fold-text/peek assertion, so the
   two capabilities D1 kept ufo *for* are covered.
3. **F3** — decide, and write it down next to S1: `virtual_lines` on or off in
   firenvim/vscode.
4. **F2** — decide `mode` for `<leader>lp`, or record the loss.
5. Update `docs/design/phase4-folding-comments.md` to a revision 4: fold F4/F6
   results into §6a, and record F1 in §7 (the "`has_parser` is easy to get wrong
   on this machine" risk was right about the direction and wrong about the
   failure mode — it predicted a missing *parser*, and what actually bites is a
   missing *query*).

Nothing here questions the phase's design decisions. D1 (keep ufo), D2 (core
`gc`), D3 (keep `vim-fold-cycle`) and S1 all re-verified sound, and the
provider-selection insight in §1.3 is worth more than the document claims —
markdown had been getting no folds at all, not merely worse ones.

---

## 4. Reproducing this review

```sh
just all                                       # 73/73

# F1, A/B on one file (ft=help via a `vim:ft=help:` modeline, buftype='')
scripts/tui-drive.sh start
scripts/tui-drive.sh cmd 'luafile <probe>'     # as built: sel=nil, 0 folds
#   then, in a fresh session, before opening the file:
#   require('ufo.fold.manager').providerSelector = function()
#     return { 'lsp', 'indent' }
#   end                                        # before:   sel=indent, 5 folds

# F3/F4, firenvim-shaped boot (tui-drive's `start` does not preserve quoting
# in --cmd, so go through a wrapper - see docs/tui-observation.md)
cat > /tmp/nvim-firenvim <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do [ "$a" = "--server" ] && exec nvim "$@"; done
exec nvim --cmd 'let g:started_by_firenvim = v:true' "$@"
EOF
chmod +x /tmp/nvim-firenvim
UCW_TUI_NVIM=/tmp/nvim-firenvim scripts/tui-drive.sh start fixture.vim
```
