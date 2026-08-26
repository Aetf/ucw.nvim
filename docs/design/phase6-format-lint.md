# Phase 6 design: formatting and linting

> Revision history
>
> * **r1** (2026-08-05) — proposal. Everything under "What is actually
>   running today" is measured on this machine (real LSP clients, real
>   `mason/bin`), not read off a README or the plan file. Three open
>   decisions (§2) are for the user before this document moves past r1.
> * **r2** (2026-08-05) — D1-D3 answered (§2): explicit `formatters_by_ft`
>   entries for lua/python/toml (not LSP-fallback-only for python/toml);
>   `format_on_save` on; `prettier` added for markdown. §3 rewritten from
>   conditional ("if D1/D2/D3...") to the concrete, final shape. `default_format_opts`
>   + a per-filetype `lua` override closes the `lua_ls` trap from §1.1; a
>   precedence check against conform's actual source ruled out giving
>   `format_on_save` its own stricter `lsp_format`, since call-site opts
>   there would have overridden (not stacked with) Rust's need for
>   `'fallback'` — corrected before it reached implementation.
> * **r3** (2026-08-05) — architecture revision from two user questions:
>   (1) can `formatters_by_ft` live in `ftplugin/<ft>.lua` instead of one
>   central table, so everything about a filetype's format behaviour is in
>   one place with its other per-filetype settings; (2) if conform is cheap
>   to load, why gate it at all. Both checked empirically rather than
>   assumed (§1.5, §2a) and **both adopted**: conform now loads eagerly
>   (measured ~0.16 ms, §2a), and `formatters_by_ft` moves out of
>   `conform.lua` into per-filetype `ftplugin/` files (§3, rewritten). The
>   investigation also caught a real bug before it shipped: **`texlab`
>   advertises formatting too** (§1.5), which the r1/r2 proposal never
>   checked — with `format_on_save` on and no explicit block, LaTeX files
>   would have started silently reformatting via `texlab` on every save,
>   contradicting the plan's explicit "latex: none" and fighting the
>   hand-tuned sentence-per-line `formatexpr` already in `ftplugin/tex.lua`.
> * **r4** (2026-08-06) — as built. §3 implemented exactly as designed:
>   `lua/ucw/plugins/conform.lua` (`lazy = false`), `lua/ucw/plugins/
>   mason-tool-installer.lua`, five `ftplugin/<ft>.lua` files (four new, one
>   extended), a fourth `fn` kind on `ucw.lsp.actions` (`lua/ucw/lsp/
>   actions.lua`). New `tests/test_format.lua` (8 cases: `formatters_by_ft`
>   shape, the two `lsp_format = 'never'` blocks against fake
>   formatting-capable clients, the unlisted-filetype fallback via fake
>   `rust-analyzer`, three real-binary CLI cases against this machine's
>   actual Mason install). `tests/test_lsp_actions.lua` updated for the
>   fourth kind. `just all`: 121 cases, green twice. Both `lsp_format =
>   'never'` guards (lua, tex) reverse-verified by hand per the Phase 4 F5
>   rule - removing either turned the matching shape assertion *and* the
>   matching fallback-blocking assertion red, for the reason predicted, not
>   an unrelated one; both reverted after confirming.
>
>   TUI pass (real files, real keypresses, `scripts/tui-drive.sh`) confirmed
>   every claim in §3/§4 against the live editor, not just the test child:
>   `<leader>lf` reformats `.lua`/`.py`/`.toml` via the real `stylua`/`ruff
>   format`/`taplo format` binaries; `:w` reformats the same three on disk
>   (`format_on_save`); a real `.tex` file with a genuinely attached
>   `texlab` client is byte-identical after `:w` (§1.5's fix holds outside
>   the fake-server test too); a real Rust project's `:w` reformats via a
>   genuinely attached `rust-analyzer` (rustfmt), confirming the
>   `default_format_opts.lsp_format = 'fallback'` path end-to-end; `.md`
>   fails loud ("Formatters unavailable for markdown file") rather than
>   silently doing nothing, since `prettier` cannot install on this machine
>   (no `node`/`npm` - the same gap already documented for `jsonls`,
>   `stylua`/`ruff`/`taplo` all installed and used for real).
>
>   One unrelated discovery during the TUI pass, **not a Phase 6 regression**:
>   opening a fresh `.lua` buffer immediately shows a `blink.cmp` completion
>   menu (`blink-cmp-menu`/`blink-cmp-documentation` floating windows) with
>   zero keys pressed, in Normal mode. Reproduced on a from-scratch buffer,
>   confirmed via `nvim_win_get_config` (real floating windows, not a capture
>   artifact) and `nvim_get_mode` (`'n'`, not `'i'`). Nothing in this phase
>   touches completion config; noted here rather than chased down, since
>   fixing it is out of scope for Phase 6 - flagging for whoever picks up
>   completion next, or for a dedicated look if it turns out to bother the
>   user in real use.
>
>   No acceptance review yet - implementation and TUI verification only.
> * **r5** (2026-08-06) — after the acceptance review
>   (`docs/design/phase6-acceptance-review.md`, finding R1). One finding, one
>   fix: `conform.lua` loses `cond = require('ucw.targets').is_full_ui`.
>   That gate, copied from `lspconfig.lua` without being checked against this
>   phase's own new `fn` action kind, meant `<leader>lf` under
>   firenvim/vscode-neovim hard-errored ("module 'conform' not found")
>   instead of the graceful no-op the other three action kinds get in the
>   same contexts (`lsp` reaches core `vim.lsp`, which always exists;
>   `picker` reaches `snacks.nvim`, which has no `cond` at all). §3.1 never
>   discusses `cond` either way - the `is_full_ui` gate was carried over
>   silently from `lspconfig.lua`, not a decision this document made and
>   missed. §3.1's rationale for `lazy = false` (conform measured at ~0.16 ms,
>   cheap regardless of context) already argued against gating it by cost;
>   the review closes the correctness gap the same measurement left open.
>   As built now: `lua/ucw/plugins/conform.lua` has no `cond` at all.
> * **r6** (2026-08-07) — second-round review of r5's own fix (the "audit the
>   fix commit too" habit from Phases 3-5, which has now produced something
>   four times running). **The r5 fix answered the question it was asked and
>   not the neighbouring one**: dropping `cond` was right for "can
>   `<leader>lf` still `require('conform')` here?", but `cond` was also the
>   only thing keeping `format_on_save` out of the embedded contexts, and
>   nothing in r5 weighed *that* half. Measured, `--cmd "lua
>   vim.g.started_by_firenvim = true"` against the real config: `BufWritePre`
>   went from **0 autocmds to 1** (`Conform`, pattern `*`) across the r5
>   commit. That matters more in firenvim than the phrase "format on save"
>   suggests — firenvim's README describes `BufWrite` as *the* mechanism it
>   uses to push a buffer back into the web page, and this repo's own
>   `lua/ucw/plugins/firenvim.lua` forces `filetype=markdown` on
>   `github.com_*.txt`, so r5 quietly put `prettier` between the user's
>   prose and every GitHub comment sync. It is inert *today* only by
>   accident: measured in that same context, `mason` is never loaded (it
>   only ever loads as a dependency of `cond`-gated specs or via its own
>   `:Mason*` commands), so Mason's bin dir is not on `PATH` and no
>   configured formatter resolves — which also makes r5's own aside about
>   "a real chance at actually formatting ... if mason's bin dir happens to
>   be on `PATH`" wrong in the one direction that would have been
>   reassuring. One `cargo install stylua` (that `PATH` already carries
>   `~/.local/share/cargo/bin`) or a global `prettier` turns it live.
>   **Fix:** `format_on_save` becomes a function returning `nil` when
>   `ucw.targets.is_full_ui()` is false (conform supports this per write —
>   `conform/init.lua`'s `BufWritePre` callback), so the *module* still
>   loads everywhere (r5's fix intact, `<leader>lf` still formats) while the
>   *automatic* rewrite stays in the full UI. Explicit versus automatic is
>   the line, not present versus absent. §3.1's `format_on_save =
>   { timeout_ms = 500 }` still describes what desktop use gets.
>
>   Also found and fixed while re-checking r5: the `cond` had a **second,
>   worse manifestation nobody had reached** — because every
>   `ftplugin/<ft>.lua` in this phase opens with `require('conform')`, a
>   gated conform threw `E5113` out of the FileType autocmd on the first
>   `.lua`/`.md`/`.py`/`.toml`/`.tex` file *opened* in an embedded context,
>   no keypress involved. `docs/design/phase6-acceptance-review.md` R1
>   asserted the opposite ("`formatters_by_ft` entries were never the gated
>   half of this; only the plugin backing them was"); measured, the ftplugin
>   half was the louder half. Already fixed by r5's own change — recorded
>   because the review reasoned about it and got it backwards, and because
>   nothing tested it.
>
>   `tests/test_format.lua`'s `embedded contexts` group grows from one case
>   to four: R1's original case, the **class** behind it (every `fn`-kind
>   action can `require` its module in an embedded context — the
>   generalisation Phase 4's G1 asked for, since `fn` is the one action kind
>   that reaches its target through a bare `require()`), the ftplugin-open
>   path, and r6's own regression (real Mason `PATH`, firenvim marker: `:w`
>   leaves the file untouched *and* `<leader>lf` still formats the same
>   buffer). All four reverse-verified: putting `cond` back turns all four
>   red; removing only the `is_full_ui` gate from `format_on_save` turns
>   exactly the last one red. The ftplugin case **was a dud when first
>   written** — it triggered FileType via `vim.bo.filetype = ft`, which
>   swallows an ftplugin error, and stayed green with the `cond` back; it
>   opens real files now. 125 cases, green ×2.

Plan file row: *Phase 6 — Linter/formatter system*, depends on Phase 3.

---

## 0. What the plan file got wrong

Same pattern as Phases 3-5: parts of the Phase 6 row are already stale.

- **The "pylsp vs. ruff LSP" open decision is already resolved and shipped.**
  There is no `pylsp.lua` anywhere in the repo. `lua/ucw/lsp/servers.lua`
  already runs `basedpyright` (types) + `ruff` (lint) — done in Phase 3
  (commit `cd8dde7`, "pyright -> basedpyright, and record the as-built
  numbers"). The plan's phrasing ("keep pylsp vs switch to ruff LSP") is
  describing a fork in the road this config drove through two phases ago.
  Nothing to ask the user here; the only live question is formatter wiring
  (§1.1, §2 D1).
- **`mason-bridge.nvim`, floated as "a newer, more automated alternative...
  worth a look at implementation time," is dead.** Its last push was
  `2024-06-11` — over two years before this document. `mason-tool-installer`
  (`WhoIsSethDaniel/mason-tool-installer.nvim`), by contrast, pushed
  `2026-01-22`, not archived, 15 open issues (normal churn for a small glue
  plugin). This isn't "not yet the default" as the plan hedged — it's the
  only one of the two still alive. No further evaluation needed; going
  straight to `mason-tool-installer`.
- **`conform.nvim` itself is current**: last push `2026-05-24`.

## 1. What is actually running today

### 1.1 Three LSP servers already advertise `documentFormattingProvider`, and one of them is a trap

Measured via a live TUI (`scripts/tui-drive.sh`), opening a real buffer of
each filetype and reading `client.server_capabilities.documentFormattingProvider`
off the attached clients:

| filetype | client | `fmt` capability |
|---|---|---|
| python | `basedpyright` | `false` |
| python | `ruff` | **`true`** |
| toml | `taplo` | **`true`** |
| lua | `lua_ls` | **`true`** |
| markdown | `marksman` | `false` |
| json/jsonc | *(no client attaches — this machine has no `node` on PATH, matching the existing comment in `lua/ucw/lsp/servers.lua`)* | n/a |

Two consequences that change what Phase 6 actually needs to do:

- **Python and TOML formatting already work today**, without conform, via
  `<leader>lf` → `vim.lsp.buf.format()`: each filetype has exactly one
  client offering formatting (ruff; taplo), so there's no ambiguity for
  `buf.format()` to resolve. The plan's framing ("add `ruff_format`... also
  evaluate ruff as a linter") undersells this — the linter half shipped in
  Phase 3, and the formatter half needs zero new server-side config, only
  conform wiring for consistency (`format_on_save`, one code path for every
  filetype) and to control formatter *options* conform exposes that raw
  `buf.format()` doesn't (range formatting args, `stop_after_first`, etc.).
- **`lua_ls` also claims formatting support, and it is not stylua.** Its
  bundled formatter is EmmyLua-style and does not read `stylua.toml`.
  Right now, pressing `<leader>lf` in a `.lua` file in this config silently
  runs *that* formatter, not stylua — despite `stylua.toml` sitting at the
  repo root looking like it's already wired up. It has never been wired up.
  This is the one filetype where conform's `formatters_by_ft` entry isn't
  just "nicer," it's fixing an existing footgun: without an explicit
  `lua = { 'stylua' }` entry (and `lsp_format = 'never'` for that filetype,
  not `'fallback'`), conform would keep silently deferring to `lua_ls`
  whenever `stylua` isn't on `PATH` yet — e.g. mid-install, or on a machine
  where `mason-tool-installer` hasn't run. `'never'` makes that failure loud
  (conform reports "no formatter available") instead of quietly formatting
  with the wrong tool.

### 1.2 Mason already has the LSP-adjacent CLI binaries; it has none of the formatter-only ones

`~/.local/share/nvim/mason/bin/` currently has (installed as LSP servers,
via `ucw.lsp.servers` → `mason-lspconfig`'s `ensure_installed`): `ruff`,
`taplo`, `basedpyright`, `clangd`, `lua-language-server`, `marksman`,
`texlab`, `ltex-ls-plus`, `vscode-json-language-server`, `rust-analyzer`.

Both `ruff` and `taplo` are dual-purpose binaries — the same executable
Mason already installs for `ruff server`/`taplo lsp` also has a `format`
subcommand, so nothing new needs installing for Python/TOML either way.

**`stylua` is not there and never will be via the existing pipeline**: it
has no LSP counterpart, so it's structurally invisible to
`ucw.lsp.server_names()` and thus to `mason-lspconfig`'s `ensure_installed`.
This is the actual gap `mason-tool-installer` closes — not "another way to
install servers" (that pipeline already works) but "a way to install
formatter/linter-only binaries that this config's LSP-centric install path
has no slot for."

### 1.3 There is no format-on-save today, anywhere

Grepped `lua/ucw/` for `format`: the only hits are the `format` entry in
`lua/ucw/lsp/actions.lua` (bound to `<leader>lf` / `<leader>lf` visual,
`vim.lsp.buf.format({async=false})`) and unrelated `string.format` calls.
No `BufWritePre`/`BufWrite` autocmd anywhere touches formatting.
**Turning on `format_on_save` in Phase 6 is a new, config-wide autoformat
behaviour, not a migration of an existing one** — flagged as D2 below
rather than assumed.

### 1.4 Rust already has its own formatter path and Phase 6 must not touch it

`lua/ucw/plugins/rustaceanvim.lua` configures no format-on-save of its own
either (checked directly — `vim.g.rustaceanvim` sets `tools`, `server`,
`dap`, nothing formatting-related), but `rust-analyzer` (the client
rustaceanvim owns) already wraps `rustfmt` and already answers
`documentFormattingProvider`. Leaving `rust` **absent** from conform's
`formatters_by_ft` and letting `lsp_format = 'fallback'` reach
`rust-analyzer` is not a gap to fill — it's already correct and is what the
plan meant by "skip rust in conform's table." If `format_on_save` (D2)
ships, it fires for Rust buffers too, through the fallback path, same as
every other unlisted filetype.

### 1.5 `texlab` formats too, and Phase 6 was about to autoformat LaTeX by accident

Same measurement as §1.1, done for `tex` after the rest of this document
was drafted, prompted by re-checking the "does an unlisted filetype's
fallback actually go somewhere safe" question the ftplugin restructuring
(§2a) raised:

| filetype | client | `fmt` capability |
|---|---|---|
| tex | `ltex_plus` | `false` |
| tex | `texlab` | **`true`** |

The plan says, explicitly, "latex: none... texlab already does
build-on-save + chktex; don't add a second formatter" — and this document's
r1/r2 draft went along with that by simply not adding a `tex` entry to
`formatters_by_ft`. That is exactly backwards given `default_format_opts.lsp_format
= 'fallback'` (needed so Rust and every other unlisted filetype keep
reaching their LSP formatter, §1.4/§3): an *absent* `formatters_by_ft`
entry means "fall through to whatever LSP client offers formatting," and
for tex that client is texlab, which does. **Without an explicit block, D2
("`format_on_save` on") would have made every LaTeX `:w` silently run
texlab's formatter** — a real regression from today's manual-only
behaviour, on the one filetype this repo has hand-tuned formatting logic
for already (`ftplugin/tex.lua`'s sentence-per-line `formatexpr`,
`safe_latex_format_expr`). `rust` and `tex` are structurally the same shape
(both have exactly one client, and it happens to advertise formatting) but
opposite desired outcomes — the plan wants Rust's fallback reached and
LaTeX's blocked, and only one of those was in the r1/r2 proposal. Folded
into the proposal as the `tex` entry in §3.

## 2. Decisions (answered 2026-08-05)

**D1 — Python/TOML: route through conform's `formatters_by_ft` (CLI
`ruff_format`/`taplo`) or leave them on the LSP fallback path (§1.1)?**
→ **Explicit entries for all three (lua/python/toml).** One mental model
("everything goes through conform"), and it exposes conform's formatter
options (timeout, args) for python/toml too, not just LSP-shaped ones.
Recorded caveat stands: this is consistency/option-surface work for
python/toml, not new capability — both already formatted correctly today
(§1.1) before this phase touched anything.

**D2 — turn on `format_on_save`?** → **On.** New behaviour (§1.3, no
filetype had autoformat-on-save before this phase). r1 floated giving
`format_on_save` its own stricter `lsp_format = 'never'`; dropped after
checking conform's actual precedence rules (call-site opts beat
`formatters_by_ft` beat `default_format_opts` — the opposite of what a
blanket override there would need), and dropped again, harder, by §1.5:
a blanket restriction on `format_on_save` cannot distinguish "Rust, where
LSP-fallback formatting is wanted" from "LaTeX, where it isn't" — that
distinction has to live per-filetype (§3), not at the `format_on_save`
call site.

**D3 — markdown: add `prettier`?** → **Yes.** Overrides r1's
"no prettier" recommendation (prose-reflow risk, §1's caveat) — the user's
call to make, not a claim that the risk isn't real. `marksman` offers no
formatting capability (§1.1), so `prettier` is what makes markdown
`format_on_save`-eligible at all; `default_format_opts`'s fallback was
never going to reach markdown either way.

## 2a. Architecture questions (answered 2026-08-05, checked empirically)

Two questions from the user, both checked against real behaviour on this
machine rather than conform's docs alone, since the docs don't cover
either:

**Q1 — can `formatters_by_ft` be declared from `ftplugin/<ft>.lua` instead
of one central table in `conform.lua`, so a filetype's formatter lives next
to its other filetype-specific settings?**

This repo already has exactly that convention for two filetypes —
`ftplugin/just.lua` and `ftplugin/tex.lua` set buffer-local options
(`textwidth`, `formatexpr`) per filetype, auto-discovered by Neovim, no
registry file involved. Checked whether conform's `formatters_by_ft` can
join that convention rather than living in a `lua/ucw/lsp/servers.lua`-style
central table:

- Read conform's source directly (`lua/conform/init.lua`). `setup()` does
  `M.formatters_by_ft = vim.tbl_extend('force', M.formatters_by_ft,
  opts.formatters_by_ft or {})` — merges into the module's own live table,
  in place. The per-buffer resolver (`get_opts_from_filetype`) reads
  `M.formatters_by_ft[filetype]` **fresh on every call**, not a value
  captured or cached at `setup()` time. So a plain `require('conform')
  .formatters_by_ft.python = { 'ruff_format' }`, run from
  `ftplugin/python.lua` any time after `conform.lua`'s own `setup()` has
  run, works exactly like declaring it centrally — confirmed by reading the
  merge and read call sites, not inferred from behaviour.
- The one real interaction: `require('conform')` from *anywhere* forces
  `lazy.nvim` to load the conform.nvim plugin immediately, bypassing
  whatever lazy trigger its spec declares — the same mechanism already
  documented in this exact repo (`lua/ucw/plugins/rustaceanvim.lua`'s
  comment on `mason-registry`, and Phase 3's P4 finding). That would have
  meant `formatters_by_ft` entries in ftplugin files silently forcing
  conform to load on file-open for every filetype that has one, no matter
  what trigger `conform.lua`'s own spec declared — which folds directly
  into Q2.

**Q2 — if loading conform is fast, is it simpler to always load it instead
of gating it on an event/cmd/filetype?**

Measured directly rather than assumed (the r1/r2 draft's "conform's own
load cost is sub-millisecond" was a guess, not a measurement — corrected
here). Added a temporary lazy.nvim spec (`lua/ucw/plugins/user/conform.lua`,
not part of the design, reverted after measuring — see note below),
`lazy = false`, and read `nvim --headless --startuptime`, 3 runs:

```
baseline (no conform):  48.19 / 50.38 / 56.19 ms  (median 50.38)
eager conform:          45.62 / 50.12 / 59.80 ms  (median 50.12)
```

No measurable difference — well inside this repo's own established
run-to-run jitter (±15 ms, Phase 5 §"observation-method notes"). The
startuptime log itself accounts for it directly:

```
sourcing .../lazy/conform.nvim/plugin/conform.lua   0.029 ms
require('conform')                                  0.133 ms
```

**~0.16 ms total** — smaller than `mason.nvim`'s own measured 1.2 ms
(Phase 3), let alone the ~50 ms baseline. **Both answers are yes**: `Q1`'s
`require('conform')`-from-ftplugin pattern already forces early loading in
practice, and `Q2`'s measurement shows that's free, so `conform.lua`'s spec
gets `lazy = false` outright rather than the `event`/`cmd` gating r1/r2
proposed — removing a lazy-loading decision that turned out not to matter,
which is the same shape of simplification as Phase 5's `remote-nvim`
removal (a cost that looked worth guarding against and measured to
nothing).

One more thing this measurement setup caught, as a side effect: a
same-machine test of `format_on_save` against the very first `:w` in a
session, to check whether `lazy.nvim`'s event-replay (already relied on for
`ft =` triggers in `lspconfig.lua`) also covers `BufWritePre`. First
attempt (using `stylua` as the formatter) showed the first write going out
unformatted — looked like a load-order bug, wasn't: `stylua` isn't
installed on this machine yet (§1.2, `mason-tool-installer` hasn't run).
Re-ran with `trim_whitespace` (a formatter conform ships with no external
binary) and the first write **was** correctly formatted. The apparent bug
was the exact "D2 interacts with the mason-tool-installer race" risk
already recorded below, not a new one — moot anyway once `conform.lua` is
`lazy = false` (§3), since there is no longer a "first trigger" to race
against.

*(Measurement housekeeping: the temporary spec used `lazy.install()` /
`lazy.clean()`, not `lazy.sync()` — the first attempt used `sync()` and it
silently bumped 12 unrelated plugins to their upstream HEAD along with
installing conform; caught via `git diff lazy-lock.json` before it went
anywhere, reverted with `git checkout -- lazy-lock.json` + `lazy.restore()`.
No lasting effect, but worth recording: `sync()` is the wrong tool for
"install one plugin to measure it.")*

## 3. Proposal (as decided)

### 3.1 `lua/ucw/plugins/conform.lua`

Minimal — no `formatters_by_ft` here at all (moved to `ftplugin/`, §3.2):

- `lazy = false` — §2a Q2. No `event`/`cmd`/`ft` gating.
- `default_format_opts = { lsp_format = 'fallback' }`. Conform's own
  default for `lsp_format` is `'never'` (confirmed in the docs) — a
  filetype with no `formatters_by_ft` entry and no override would
  otherwise get **no formatting at all** from conform, a silent regression
  from today's `buf.format()`-based `<leader>lf` that reaches every
  attached client. `'fallback'` (use LSP only when no configured formatter
  exists) is what preserves that reach for clangd/ltex/rust-analyzer and
  everything else without a `formatters_by_ft` entry.
- `format_on_save = { timeout_ms = 500 }` — D2 is "on," with **no**
  `lsp_format` override (§2 D2, §1.5): it resolves through the same
  per-filetype rules as manual `<leader>lf`, which is what lets Rust keep
  its fallback while LaTeX's block (§3.2) still applies. *(As built since
  r6: the same table, returned from a function that returns `nil` when
  `ucw.targets.is_full_ui()` is false — see r6 for why the embedded
  contexts get the module but not the save hook.)*
- `<leader>lf` in `which-key.lua` moves from the raw `lsp` action kind to a
  new **fourth `ucw.lsp.actions` kind**, following the precedent Phase 5 set
  when `picker` became the third kind alongside `lsp`/`cmd`: a `fn` kind
  that stores a `require(...)` module path + function name, resolved at
  press time for the same reason `lsp`/`picker` are (a removed/renamed
  function fails by name instead of going silently inert). `format`'s `fn`
  becomes `{ mod = 'conform', fn = 'format' }` with **no `args`** — the
  fallback behaviour lives entirely in `default_format_opts`/`formatters_by_ft`,
  not duplicated at the call site.

### 3.2 `formatters_by_ft`, one entry per `ftplugin/<ft>.lua`

Each file mutates `require('conform').formatters_by_ft` for its own
filetype only. Safe regardless of call order relative to `conform.lua`'s
own `setup()`, since `conform.lua` is `lazy = false` and therefore always
loaded before any buffer (and its `ftplugin`) opens (§2a Q1/Q2):

- **`ftplugin/lua.lua`** (new file): `formatters_by_ft.lua = { 'stylua',
  lsp_format = 'never' }`. The `'never'` is load-bearing, not decoration —
  conform supports embedding `lsp_format` inside a filetype's own
  `formatters_by_ft` entry specifically to override
  `default_format_opts` **for that filetype only**, and without it here
  `default_format_opts.lsp_format = 'fallback'` reopens the
  `lua_ls`-formats-instead-of-stylua trap from §1.1.
- **`ftplugin/python.lua`** (new file): `formatters_by_ft.python = {
  'ruff_format' }` — D1. No `lsp_format` override needed: unlike `lua_ls`,
  the LSP-fallback client (`ruff`) *is* the same tool conform's formatter
  shells out to, so falling back to it if `ruff_format` were ever
  unavailable reaches the right tool anyway, not a trap.
- **`ftplugin/toml.lua`** (new file): `formatters_by_ft.toml = { 'taplo' }`
  — D1, same reasoning as python (fallback client `taplo` = the CLI conform
  shells out to).
- **`ftplugin/markdown.lua`** (new file): `formatters_by_ft.markdown = {
  'prettier' }` — D3.
- **`ftplugin/tex.lua`** (existing file, extended): add
  `require('conform').formatters_by_ft.tex = { lsp_format = 'never' }`
  (no formatter list — this entry exists purely to block the fallback).
  This is the fix for §1.5: without it, `default_format_opts.lsp_format =
  'fallback'` reaches `texlab`'s formatter on every save. Placed in the
  same file as the existing `safe_latex_format_expr`/`formatexpr` setup
  precisely because both are "how this config decided LaTeX gets
  (re)formatted," and the existing code is what already explains *why*
  LaTeX is special (texlab handles build+lint, not reformatting; the
  sentence-per-line rewrap is hand-rolled because no LSP or CLI formatter
  does it).
- **No `ftplugin/rust.lua`**: absence is the correct state (§1.4) —
  `default_format_opts.lsp_format = 'fallback'` already reaches
  `rust-analyzer`, and there is nothing to override.

### 3.3 `lua/ucw/plugins/mason-tool-installer.lua`

Unaffected by §2a (a different plugin, doing a different job — installing
binaries, not formatting):

- `ensure_installed = { 'stylua', 'prettier' }` (D3: yes). Deliberately
  **not** `ruff`/`taplo` — those are already installed as LSP servers by
  the existing `mason-lspconfig` pipeline (§1.2); listing them again here
  would just be two installers racing to write the same `mason/bin/` entry.
- Trigger: `event = 'VeryLazy'`, matching `mason-lspconfig.lua`'s own
  reasoning verbatim — nothing on the file-open hot path needs the binary
  present synchronously (conform reports "not installed" gracefully rather
  than erroring the buffer), and mason-tool-installer's own install check
  costs real time.
- `dependencies = { 'williamboman/mason.nvim' }`, same reason
  `mason-lspconfig.lua` declares it: this is what actually gets
  `mason.setup()` to run and put `mason/bin` on `PATH`.

### 3.4 No `nvim-lint`

Unchanged from the plan and still correct: every filetype this config
touches already gets diagnostics from an LSP client (`ruff` for Python
lint, `clangd`/`basedpyright`/etc. for the rest). Adding `nvim-lint` would
mean a second diagnostic source with its own severity mapping and its own
`BufWritePost`/`InsertLeave` triggers to reconcile against the LSP ones
already running — real complexity for filetypes that have zero linting gap
today.

## 4. Verification plan

- `tests/test_format.lua` (new): open a deliberately misformatted `.lua`
  fixture (mixed indent, double-quoted string, trailing whitespace conform
  is expected to touch given the repo's own `stylua.toml`), call the same
  `require('ucw.lsp.actions').call('format')` path the keymap uses (not
  `require('conform').format()` directly — the point is testing the wired
  path, same lesson as Phase 3's `tests/test_deprecations.lua` testing the
  configured path rather than the library in isolation), assert buffer
  content matches `stylua --check`'s expectation. Matching cases for
  `ruff_format` (python), `taplo` (toml), `prettier` (markdown).
- **A `tex` case asserting the opposite**: open a scruffy-but-valid `.tex`
  fixture, `:w`, assert the on-disk content is **byte-identical** to what
  was written (i.e. `texlab` did *not* reformat it). This is the direct
  regression guard for §1.5 — the one finding in this document that would
  have shipped silently wrong without a TUI check that happened to look at
  `tex` specifically.
- A case that `:write`s a misformatted buffer to a temp file and asserts
  the *on-disk* content changed (not just the in-buffer one —
  `format_on_save` is a `BufWritePre` hook, and the two can diverge if the
  autocmd priority/timing is wrong, which is exactly the kind of thing a
  buffer-only assertion would miss).
- A case opening a Rust buffer, `:w`, asserting the on-disk content was
  reformatted via `rust-analyzer` — the path most likely to silently break
  if a future edit adds any `lsp_format` to `format_on_save`'s own table
  (§2 D2), the same mistake this document caught in r2 before it shipped.
- **A consistency test, since §3.2 removed the single central table**:
  open one buffer per filetype in `{lua, python, toml, markdown, tex}`,
  assert `require('conform').formatters_by_ft` has exactly those five keys
  present (four with a real formatter, `tex` with only the `lsp_format`
  override) — the `ftplugin/`-per-filetype approach traded away the kind
  of single-table `grep`-ability `ucw.lsp.servers` has, so this is what
  stands in for it: a forgotten `ftplugin/<ft>.lua` file, or one that
  silently fails to run, fails this test instead of shipping quietly.
- Reverse-verify per the Phase 4 rule (F5): revert the `lua_ls`
  `lsp_format = 'never'` guard in `ftplugin/lua.lua` and confirm the lua
  test above goes red for the *right* reason (`lua_ls`'s formatter ran,
  content doesn't match stylua's); separately, revert the `tex` block and
  confirm the tex test goes red for the right reason (texlab reformatted
  it).
- TUI pass: real `.lua`/`.py`/`.toml`/`.md`/`.rs`/`.tex` files, `<leader>lf`,
  watch the buffer change; `:w` a misformatted file of each (tex excluded,
  by design) and watch it reformat without pressing the key.
- `just ci` full suite, at least twice (Phase 3's P7 lesson: green once is
  not a signal).

## 5. Risks

- **§1.5 generalizes**: any filetype with exactly one LSP client that
  happens to advertise formatting will silently reach it once
  `default_format_opts.lsp_format = 'fallback'` + `format_on_save` are both
  on, whether or not that's wanted. This document only checked the
  filetypes `ucw.lsp.servers` already lists (§1.1, §1.5) — a *future*
  server added to that list, with formatting capability nobody thought to
  check, becomes a silent autoformat source the same way `texlab` almost
  was here. No structural fix proposed; the §4 consistency test only
  covers the five filetypes this phase touches, not future additions —
  worth a callback here for whoever adds the next LSP server to check its
  `documentFormattingProvider` before assuming `fallback` is harmless for
  it.
- **`formatters_by_ft` split across `ftplugin/` files loses the
  `grep`-one-file visibility a central table had** — offset by the §4
  consistency test, but worth naming as a real, accepted tradeoff (Q1) and
  not a free lunch: `lua/ucw/lsp/servers.lua` stayed centralized precisely
  because it has ten servers and cross-references two other files
  (`mason-lspconfig`'s `ensure_installed`, `ucw.lsp.filetypes()`); this
  phase's formatter registry is five filetypes and one property
  (`formatters_by_ft`) with no comparable cross-referencing need, which is
  the actual argument for decentralizing it and not just "the user asked."
- **R-analog to Phase 5's R1/Phase 4's F2**: conform's `formatters_by_ft`
  values can be a list (fallback chain) or a function; getting the shape
  wrong for `ruff_format`/`taplo`/`prettier` fails silently in the same
  family of ways `sources.buffers.preview = false` did in Phase 5 — wrong
  type, not wrong value, accepted without error. Verification (§4) must
  assert the *formatted output*, not just "conform ran without erroring."
- **The precedence rule (call-site opts beat `formatters_by_ft` beat
  `default_format_opts`) is easy to get backwards while writing new code**,
  exactly because the naive reading ("more specific wins") points the wrong
  way here — `format_on_save`'s table is call-site opts, `formatters_by_ft`'s
  embedded `lsp_format` is filetype-level, and it's the *less specific one
  that loses*. Any future edit that adds `lsp_format` to `format_on_save`'s
  own table (even meaning to affect one filetype) would silently override
  every filetype's override at once — both `lua`'s `'never'` and `tex`'s
  `'never'` and Rust's implicit `'fallback'`. The Rust and tex on-disk
  tests in §4 are what catch this specific failure mode.
- **D2 "on" interacts with the mason-tool-installer race**: on a fresh
  machine (or right after `stylua`/`prettier` are added to
  `ensure_installed`), `format_on_save` can fire before
  `mason-tool-installer` finishes its first install. With `lsp_format =
  'never'` for lua/tex this fails loud (a conform notification, no silent
  wrong-formatter fallback) rather than corrupting anything — reproduced
  directly during §2a's measurement (first `:w` with `stylua` uninstalled
  produced unformatted output, no error surfaced in `:messages` either,
  just silence). Worth confirming during TUI verification on this exact
  machine, since neither `stylua` nor `prettier` is installed here yet
  (§1.2).
