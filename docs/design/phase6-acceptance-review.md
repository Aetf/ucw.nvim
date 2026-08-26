# Phase 6 acceptance review

Reviewed: commit `ce77f9b` ("Phase 6: conform.nvim, one ftplugin file per
formatted filetype") against `docs/design/phase6-format-lint.md` (r4) and the
plan file's Phase 6 row.

**Verdict: accept, with one fix applied.** One finding (R1), a real regression
reachable in a context this config actively supports (firenvim), found by
checking a seam the design doc never crossed: every other action kind behind
`ucw.lsp.actions` stays reachable under `is_full_ui() == false`, and the new
`fn` kind does not, because its one and only backing plugin does. Everything
else in the design doc — the two `lsp_format` traps (§1.1/§1.5), the
precedence rules, the `formatters_by_ft` shape, the eager-load measurement —
re-verified true.

Same rule as previous reviews: everything marked **measured** below was
produced on this machine (Neovim 0.12.3) against the real config, via
`just all` and direct headless probes with `--cmd` (to set target markers
*before* `init.lua` runs, which `-c` cannot do). Nothing here is inferred
from reading the diff.

---

## 1. Findings

| # | Finding | Kind | Severity |
|---|---|---|---|
| R1 | `<leader>lf` under firenvim/vscode-neovim **hard-errors** ("module 'conform' not found") instead of the graceful no-op every other action kind gets in the same contexts | regression, narrow but live | medium |

Only one finding. This phase's own r1-r4 iteration already caught and closed
two real traps (`lua_ls`, `texlab`) before shipping, and the design doc's own
precedence analysis (§2 D2, §5) was checked against conform's source rather
than assumed — there was less left for a second pass to find than in
Phases 3-5, and the pattern those reviews established (**the new test guards
what changed on purpose; findings land on what changed as a side effect**)
still held: this is the one seam the design doc never crossed.

---

### R1 — `<leader>lf` hard-errors under firenvim/vscode-neovim (medium)

`conform.lua` carried `cond = require('ucw.targets').is_full_ui`, copied
verbatim from `lspconfig.lua`/`mason-lspconfig.lua`. Under `is_full_ui() ==
false` (firenvim, vscode-neovim — both actively configured in this repo,
`lua/ucw/plugins/firenvim.lua` and `lua/ucw/lsp/vscode.lua`), lazy.nvim never
loads conform, so `conform.nvim`'s directory never reaches `runtimepath` and
`require('conform')` fails at the Lua level, not the "no client attached"
level.

That collides with a design choice from *this same phase*: `ucw.lsp.actions`'
new `fn` kind resolves its target by `require(mod)` and **raises on failure,
on purpose** — the same reasoning already applied to `picker` in Phase 5
("a source that disappears upstream would otherwise be a silently dead key").
The reasoning is sound for a plugin that is supposed to be there and isn't.
It was never checked against a plugin that is *deliberately* not there for
this context, which is a different failure mode with a different correct
response.

**The other two dynamic action kinds do not have this problem, and the
asymmetry is what made this findable:**

* `lsp` actions (`rename`, `code_action`, `declaration`, ...) call into
  `vim.lsp`, a core Neovim module that always exists regardless of whether
  `lspconfig.lua` ever loads. With zero attached clients (`is_full_ui() ==
  false` means no server ever starts), `vim.lsp.buf.format()` — what
  `<leader>lf` called before this phase — printed `[LSP] Format request
  failed, no matching language servers.` and returned. No error.
* `picker` actions call into `Snacks.picker`, and `snacks.nvim`
  (`lua/ucw/plugins/snacks.lua`) has **no `cond` at all** — it loads
  everywhere. A picker source with no results is an empty picker, not an
  error.
* `fn` (this phase's only entry, `format`) calls into `conform`, and
  `conform.lua` is the only backing plugin of the four action kinds that is
  both `cond`-gated *and* reached through a bare `require()` that raises on
  miss.

**Measured**, before the fix — `vim.g.vscode` has to be set via `--cmd`
(before `init.lua` runs and lazy evaluates `cond`), not `-c` (which runs
after, too late to matter):

```
$ nvim --headless --cmd "lua vim.g.vscode = true" \
    -c "lua vim.defer_fn(function()
          local ok, err = pcall(function()
            require('ucw.lsp.actions').call('format')
          end)
          -- write ok/err to a file, since headless has no way to see the
          -- return value directly
        end, 1500)"

false | .../lua/ucw/lsp/actions.lua:145: LSP action "format": require("conform") failed: module 'conform' not found: ...
```

A full Lua traceback (13 lines of `package.path` search misses), for a key
whose pre-Phase-6 behaviour under the same conditions was a single quiet
notify. `which-key.lua` has no `cond` either, so `<leader>lf` is bound and
reachable in every context — this is not a hypothetical path, it is the same
key firenvim's browser text-editing sessions would reach for.

**Fix:** drop `cond = is_full_ui` from `conform.lua`. Conform has no UI
surface of its own — it shells CLI formatters or falls back to whichever LSP
client (if any) is already attached — so, unlike `lspconfig.lua` (which
starts LSP UI features that would be redundant/wrong inside an embedded
host), there is nothing about firenvim/vscode-neovim conform needs to avoid.
It also does not reopen the cost question the design doc already answered:
§2a Q2 measured conform's own load cost at ~0.16 ms regardless of context,
which is why it is `lazy = false` in the first place.

`ftplugin/<ft>.lua` files (§3.2) already run unconditionally regardless of
`ucw.targets` — Neovim's own `FileType` autocommand doesn't know about this
config's context predicates — so `formatters_by_ft` entries were never the
gated half of this; only the plugin backing them was. With the `cond`
dropped, a `.lua`/`.py`/`.toml` buffer opened under firenvim now has a real
chance at actually formatting (if `mason`'s bin dir happens to be on `PATH`
for that session) rather than a guaranteed crash either way — a genuine
capability gain, not just a quieter failure, though the review's concern was
the crash, not the capability.

---

## 2. Re-measured and confirmed true

Recorded so a later pass does not redo it:

* **Both `lsp_format = 'never'` traps hold.** Reverse-verified independently
  of the design doc's own r4 claim: flipped `ftplugin/lua.lua`'s override to
  `'fallback'`, reran `tests/test_format.lua` — exactly two cases went red
  (`shape` and `lsp_format blocking | lua stays unformatted...`), both for
  the predicted reason (the fake `lua_ls`-shaped client's edit applied).
  Reverted, suite back to 8/8 (now 9/9 after R1's new case).
* **`format_on_save`'s call-site opts really don't carry an `lsp_format`
  override** — read `conform/init.lua`'s `BufWritePre` handler directly: it
  builds `sync_format_opts` from `opts.format_on_save` (`{timeout_ms = 500}`
  here) merged with `{buf, async = false}`, then calls the same `M.format`
  manual `<leader>lf` calls. No separate resolution path exists for
  format-on-save vs. manual format, confirming §2 D2's precedence analysis
  was checked against real behaviour, not just the docs.
* **`formatters_by_ft` shape is exactly as designed**: five filetypes
  (`lua`, `python`, `toml`, `markdown`, `tex`), the array/hash split matches
  §3.2 field-by-field (`tests/test_format.lua`'s `shape` group already
  covers this and re-ran green).
* **The real binaries are real**: `stylua`, `ruff`, `taplo` present in
  `~/.local/share/nvim/mason/bin/`; `prettier` absent (no `node` on this
  machine, the same documented gap as `jsonls`) — matches §1.2/r4 exactly.
* **`taplo`'s missing `range_args`** (unlike `stylua`/`ruff_format`, which
  both define one) is not a bug: conform's own runner falls back to
  "format the whole buffer, apply only the diff hunks touching the visual
  range" when a formatter has no `range_args` (`conform/runner.lua`'s
  `only_apply_range` path) — read directly, not inferred. Visual-mode
  `<leader>lf` on a `.toml` file degrades gracefully, not silently or
  incorrectly.
* **No conflicting `BufWritePre`/`BufWrite` autocmd exists anywhere else in
  `lua/ucw/`** — grepped; conform's own autocmd is the only one, so
  format-on-save cannot double-fire or race against another save hook.
* **The silent-when-unconfigured tex path is correct, not an oversight**:
  `formatters_by_ft.tex = { lsp_format = 'never' }` has no formatter name
  list, and conform's own "formatters unavailable" notify is gated on
  `not vim.tbl_isempty(formatter_names)` — read directly in
  `conform/init.lua`. An *absent* formatter list suppresses the notify
  entirely, so `:w` on a `.tex` file with no formatter configured produces
  no format, no error, no notify spam on every save — matching what a
  filetype with its own hand-rolled `formatexpr` and no place in this
  phase's formatter set should do.
* **`just all`: 121/121, green ×2**, before this review touched anything.

---

## 3. Fix applied

Commit: see `git log` following this document.

| # | Fix |
|---|---|
| R1 | `conform.lua` loses `cond = require('ucw.targets').is_full_ui` — nothing else in the file changes. `tests/test_format.lua` grows an `embedded contexts` group: reboots the test child with `vim.g.vscode = true` set *before* `require('ucw').boot()` (the same technique `tests/test_fold.lua`'s "embedded contexts" group uses, since the standard `pre_case` hook has already booted the full-UI config before any test body runs), then asserts `require('ucw.lsp.actions').call('format')` does not raise |

---

## 4. Verification of the fix

**Suite: 122 cases, green ×2** (121 + 1).

**Reverse verification** — reintroduced `cond = is_full_ui`, reran only the
new case: it failed for exactly the predicted reason (`false` where `true`
was expected — the `pcall` around `.call('format')` caught the
`require('conform')` error). Reverted, suite back to 122/122.

**Live, headless, real config** (not the test child):

```
before: false | .../actions.lua:145: LSP action "format": require("conform") failed: module 'conform' not found: ...
after:  true | nil
```

`vim.g.vscode = true` set via `--cmd` (before `init.lua`, so lazy.nvim's
`cond` evaluation actually sees it — `-c` runs too late and was the first,
invalid version of this probe during the investigation).

**Not independently re-verified in a live firenvim/vscode-neovim host**: no
browser or VS Code available in this environment to drive an actual takeover
session. The headless probe reproduces the exact mechanism (`vim.g.vscode`
read by `ucw.targets.is_full_ui()` at `lazy.setup()` time, same code path a
real host triggers) rather than the host itself, which is the same
limitation every `cond`-dependent test in this suite already has
(`tests/test_fold.lua`'s "embedded contexts" group is headless-only too).

**Deliberately not changed:**

* `mason-tool-installer.lua` keeps `cond = is_full_ui`. Its job is
  installing `stylua`/`prettier` into the shared Mason bin directory, which
  persists across sessions regardless of which one ran the install — a
  firenvim session benefits from a full-UI session having installed the
  binaries once, without needing to also spend a `VeryLazy` install check on
  every firenvim launch. Only conform's own hard-crash-on-`require` was the
  live bug; the binaries not being freshly re-checked in an embedded context
  is not one.
* The unrelated `blink.cmp` completion-popup-on-fresh-buffer bug (documented
  in `docs/design/phase6-format-lint.md`'s r4, confirmed real by the user)
  is still out of scope. It surfaced again during this review's own TUI
  attempt to verify the fix in the full-UI path (a stray keystroke landed in
  the open completion popup and corrupted an in-buffer, never-saved scratch
  file used only for the check) — recorded here as one more repro, not
  chased down. The full-UI formatting path itself needed no live TUI
  re-check: `cond` only gates `is_full_ui() == false`, so removing it is
  provably a no-op for `is_full_ui() == true` (normal desktop use, where the
  cond already evaluated true), and `tests/test_format.lua`'s three
  real-binary cases already exercise `<leader>lf` end-to-end against real
  `stylua`/`ruff`/`taplo`, green ×2, both before and after this fix.
