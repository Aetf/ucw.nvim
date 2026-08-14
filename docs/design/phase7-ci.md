# Phase 7 design: CI, and the checks that have to exist before it

> Revision history
>
> * **r11** (2026-08-14) — §6's standing blink.cmp popup bug root-caused and
>   fixed: it is triggered by using the cmdline, not by `.lua`, and the cause is
>   an upstream race in `blink.cmp`'s `vim.on_key` handler. §9.9.
> * **r10** (2026-08-14) — the `stable` screenshot flake and the two `nightly`
>   failures were one mechanism: a notification float over the two cases that
>   read the screen. Root-caused to a real 0.13 removal (`BufModifiedSet`) that
>   breaks the pinned neo-tree branch; screen tests now dismiss notifications
>   and `tests/test_neotree.lua` owns the error question. §9.8.
> * **r9** (2026-08-14) — first green CI. D1 done and caching decided (no cache:
>   `test` is ~2.5 min on a runner), so §8.5 is closed; `continue-on-error`
>   confirmed against a real nightly failure; one screenshot flake outstanding
>   with the assertion now carrying evidence. §9.7.
> * **r8** (2026-08-14) — the first real CI run was red, and it was R1 a third
>   time: lazy.nvim resets `rtp` to `stdpath('config')`, so the *test* child gets its
>   plugins from there too and the acceptance review's "the `test` job is
>   unaffected" was wrong. Fixed by giving `test` the same `nvim_config_env`;
>   §9.6. `lint`/`format` were green, so §9.1 held.
> * **r7** (2026-08-13) — **acceptance review fixes.** `docs/design/phase7-acceptance-review.md`
>   found four; all four fixed, §9 below is the record. The one that matters is
>   R1: §8.2 noticed the `lint` job had no plugins and answered "depend on
>   `just plugins`", without asking whether `just plugins` works on a runner. It
>   did not — bare `nvim` loads `$XDG_CONFIG_HOME/nvim`, which on this machine
>   *is* this repo and on a runner is nothing, so every `lint` run would have
>   been red. §8.3's bare-runner probe could not have caught it because it varied
>   `XDG_DATA_HOME` only. R2 is the other half of §8.1's own triage:
>   `undo_stage_hunk → stage_hunk` is not mechanical either, and shipped a
>   command that stages when it says undo.
> * **r6** (2026-08-13) — **as built.** §3.5's six steps landed as seven commits
>   (`2529804`..`52dc6a5`); §8 is the new as-built section and is the only part
>   of this document written after the code. Everything above it is left as the
>   record of what was believed before. Four of its statements turned out to be
>   wrong, and each was caught by a guard rather than by a red CI run, which is
>   the outcome §5 was asking for: `$VIMRUNTIME` cannot be captured the way §1.5b
>   says; `pathStrict` is not the variable §1.5b thought it was; §1.5
>   misidentified one of the two gitsigns deprecations; and `mise-action` is on
>   `@v4`, not r5's `@v2`. One gap: §3.2's `lint` job has no way to get the
>   plugin library it depends on, the same shape as the `nvim` hazard that
>   section already named.
> * **r5** (2026-08-13) — two follow-ups to r4's own open items, both closed
>   empirically rather than left for implementation time. D2's "check at
>   implementation time" is answered: `stable` on `neovim/neovim` is a
>   rolling tag, not a snapshot, and today it resolves to `v0.12.4` — the
>   `GET /repos/neovim/neovim/releases/tags/stable` API response says so
>   directly, so the two CI legs are `v0.12.4` and `nightly` in fact, checked
>   before the workflow file is written rather than after. **D13** (new,
>   user): `jdx/mise-action`'s own `version:` input defaults to `latest` and
>   was left unpinned in r4's sketch, which is a gap in the same shape as the
>   one that got `stylua-action` deleted — `mise.toml`'s "no `mise trust`
>   needed" claim is measured on a specific mise (`2026.7.11`, the comment
>   says so), and an unpinned action means CI's mise can drift away from the
>   version that claim was tested against. Pinned, for the same
>   by-construction reasoning D2/§5 already uses for `stylua`.
> * **r1** (2026-08-07) — proposal. Everything under §1 is measured on this
>   machine today (four full suite runs, a real `lua-language-server --check`,
>   a real `stylua --check`, real cold plugin/Mason installs into scratch
>   `XDG_DATA_HOME`s), not read off the plan file or an action's README. §2
>   lists the decisions that are the user's before this document moves to r2.
>   The plan file's Phase 7 turns out to be right about two things and to be
>   missing four (§0) — including the one that blocks everything: **this
>   branch has never been pushed.**
> * **r4** (2026-08-13) — re-measured on top of Phase 6.5 (accepted
>   `4b5f305`) and of the machine-side `PATH` fix Phase 6.5 was waiting on
>   (yadm `947bf33`, same day). Three of r3's own decisions turn out to be
>   **already built, differently and better** — D8's in-child formatter
>   install never happened because `mise.toml` made it unnecessary, and
>   `REAL_MASON_BIN` is already deleted (§1.2). One r3 statement is now
>   backwards (`npm`, §1.2). One r3 risk **closed by itself** (D2/§5: Arch
>   is on 0.12.4). And the lint re-triage this revision was required to do
>   found the thing r3 could not have: **§1.5's configuration B was measured
>   with two settings r3 never wrote down**, and without them the same
>   config silently produces a *different* 20 problems that looks just as
>   plausible (§1.5b). One gap between what r3 decided and what shipped
>   (D8's absent-formatter notification) is now on this phase's build list.
> * **r3** (2026-08-08) — four user corrections, three of which contradict
>   r2 and all four checked empirically before being written down. **D8**:
>   formatter availability is behaviour, not setup — the suite installs its
>   own formatters and covers *both* the present and the absent state
>   (§1.2, §3.4); `REAL_MASON_BIN` and the proposed `just tools` recipe are
>   deleted, since r2 would have relocated a host dependency rather than
>   removed it. **D9**: the lint config stays in the repo so the same
>   diagnostics appear while editing (§1.5a, §3.3) — measured with a probe
>   that discriminates, after two dud probes that did not. **D10**:
>   `just deps` takes its pin from `lazy-lock.json`'s `mini.nvim` rather
>   than a second hand-written SHA (§1.6). **D4 reversed**:
>   `call_parentheses` stays `NoSingleTable`.
> * **r2** (2026-08-07) — D1-D5 answered by the user (§2), D6/D7 taken at
>   their defaults. The branch gets pushed *and* a PR opened; stylua is
>   adopted in full including `tests/`, with `call_parentheses` switched to
>   `Always`; the lua_ls gate goes in at configuration B, fixing what can be
>   fixed this phase and recording the rest (§7); the matrix is `stable` +
>   `nightly` only. §2 rewritten from questions to decisions, §3 from "as it
>   stands, pending §2" to the concrete shape, §5 gains the risk that follows
>   from dropping a `v0.12.3` leg, and §7 is new.

## 0. What the plan file got wrong

The plan's Phase 7 is short: pin mini.nvim in `just deps`, add a
`.github/workflows/ci.yml` with a `['v0.12.3', 'nightly']` matrix,
`fail-fast: false` plus `continue-on-error` on nightly, no screenshot
goldens. Measured against the repo as it stands:

1. **There is nothing on GitHub to run CI against.** `git ls-remote` shows
   `origin` has exactly one branch, `main` at `bc33c93` — *"remote-nvim:
   tweak to work with HAOS"*, i.e. the pre-modernization config, still
   containing the `remote-nvim` that Phase 5 deleted for never having been
   used. All 24 commits of Phases 0-6 (`c7edbf3..df33355`) exist only in this
   working copy. Phase 7 is therefore not "add a workflow file"; its first
   step is publishing six phases of work to a public repo. See D1.
2. **The suite is not host-independent, and CI is a bare host.** Five cases in
   `tests/test_format.lua` deliberately point the child's `PATH` at *this
   machine's* real `~/.local/share/nvim/mason/bin` (§1.2). On a fresh runner
   that directory does not exist and those five go red. The plan does not
   mention it.
3. **`v0.12.3` is no longer "stable".** `v0.12.4` shipped 2026-07-05; this
   machine is on 0.12.3 because Arch `extra` still packages `neovim
   0.12.3-1`. So the pin is still the right choice for "what the author
   actually runs", but it is now a *different* leg from "what everyone else
   gets", and the matrix should say which is which (D2).
4. **Formatting is not in the plan at all**, though goal 13 is. `stylua.toml`
   has existed, unenforced, for years: 44 of 91 Lua files do not match it
   (§1.4). Worse, since Phase 6 the config *itself* enforces it on save, so
   the repo is already converting, one human save at a time.
5. **Linting the config's own Lua is not in the plan either.** A 30-second
   `lua-language-server --check` finds a live bug (a keymap in the neo-tree
   window that throws), two upstream deprecations, and one leftover
   which-key v1 call that Phase 1's conversion and Phase 3's audit both
   missed (§1.5).
6. Still correct and adopted as written: the `mini.nvim` pin (§1.6),
   `fail-fast: false` + `continue-on-error` for the nightly leg, and **no**
   screenshot-golden step (`tests/test_tui_screenshot.lua` asserts structured
   content on purpose; nothing changes).

**r4 (2026-08-13): this section still stands, with two of its six items now
resolved elsewhere.** Item 2 (the suite reaching this machine's Mason) was
fixed by Phase 6.5, not by this phase — see §1.2. Item 3's premise moved:
Arch is on 0.12.4 now, which settles D2 rather than complicating it (§5).
The rest — nothing on GitHub to run against, no formatting gate, no lint
gate — is unchanged and is what Phase 7 is still for. Re-verified today:
`git ls-remote origin` still shows exactly one branch, `main` at `bc33c93`,
and `.github/` does not exist.

## 1. What is actually true today (measured 2026-08-07, §1.2/§1.5a/§1.6 extended 2026-08-08, whole section re-measured 2026-08-13)

### 1.1 The suite is green, takes ~93 s, and its exit code is honest

125 cases across 13 files — 10 `new_integration_test` (full config boot into
a scratch `XDG_DATA_HOME`), 3 `new_unit_test`. Four consecutive `just all`
runs: **93 s / 93 s / 96 s / 92 s, all green, exit 0**.

Exit code checked directly rather than assumed, because a CI step that
always passes is worse than no CI: a temporary `tests/test_zzfail.lua` with
one `eq(1, 2)` makes the same headless invocation `just ci` uses **exit 1**
(mini.test `cquit`s from its headless reporter). So `just ci` plugs into a
workflow step unmodified — no reporter shim, no output parsing.

The known intermittent (`test_boot` hanging at *"child stuck in mode r?"*,
seen twice across Phase 5's many runs) did **not** reproduce in these four
runs. It is rare, not gone; §5 says what to do if CI is where it next
surfaces.

### 1.2 (r4) The reach outside the child is already gone, and not by this phase's hand

**Everything below the r4 note is r3's text, kept because the reasoning is
still the record of why the problem mattered — but the problem it describes
no longer exists, and the mechanism that removed it is not the one r3
designed.**

Phase 6.5 got there first, as a side effect of `mise.toml` and "`just`
establishes the environment, it does not assume one" (6.5 §2.3a). Measured
today against the file as it stands:

* **`REAL_MASON_BIN` and `use_real_mason_bin()` are already deleted** — a
  grep over `tests/` finds neither. 6.5 removed them when it made `just
  test` run under `mise exec --`.
* **`MasonToolsInstallSync` is never invoked in the suite.** r3's D8
  proposed the child install `stylua`/`ruff`/`taplo` into its own scratch
  Mason (1.14 s, measured, real). That work was never needed: the three are
  pinned in `mise.toml`, `just test` runs through `mise exec --`, and the
  child inherits `PATH` the way any other process does. `test_format.lua`'s
  header comment now says so.
  The single grep hit is a **comment in `tests/test_health.lua:14`**, and it
  is worth reading rather than skipping: 6.5 considered driving real Mason
  installs for that file's fixtures and rejected it — *"would download a
  real binary per case to observe a code path that never looks at one."*
  Same objection applies to D8's install case, arrived at independently, in
  a different file, by whoever wrote Phase 6.5. Two rejections of one
  mechanism is a stronger reason to drop it than either alone (§3.4).
* So the *`'real CLI formatters'`* group calls real, version-pinned binaries
  with **no setup step at all**, and a bare runner gets the same three
  versions this machine does — which is more than r3's design would have
  achieved, since a child-side Mason install resolves to whatever the
  registry serves that day.

**What this costs, and it is a genuinely new entry on the bill: `mise` joins
the bare-runner contract.** r3's §3.2 workflow sketch has no mise step;
without one, `just test` cannot resolve `mise` and every job fails at the
first recipe. The contract is now `checkout` + `nvim` + `just` + `mise`,
then `just deps` (6.5 §8 already said this; §3.2 is where it has to land).

**The gap r3 decided and nobody built.** D8 named a two-state axis: buffer
unchanged **and** exactly one WARN `Formatters unavailable for <ft> file`.
Grepping the suite for that string finds nothing. What exists is
`no_formatters_on_path()`, used exactly once, inside `'lsp_format
blocking'`, to prove a *different* property (never silently falls back to a
formatting-capable LSP client). The notification half was decided in r3 and
skipped in 6.5's execution — 6.5 §8 called this axis "survives unchanged",
which was true of the half that existed. **User decision (2026-08-13): build
it in this phase** (§3.4).

**And one r3 sentence is now false in the other direction.** §1.2 below
argues from "a GitHub runner has `npm` and this machine does not". Today
`mise exec -- which npm` resolves (mise-managed node 25.9.0, installed
before Phase 6.5 and only reachable since the `PATH` fix). The conclusion
survives anyway, but for a *different and better* reason than "the host has
no npm": `mason-tool-installer`'s spec is `cond = is_full_ui`, which is
never true in a headless test child. Markdown therefore has no formatter in
the test context **by construction**, on this machine and on a runner alike,
regardless of what `npm` either can reach. That is a structural guarantee
where r3 had an environmental accident, so the "markdown is the natural
no-formatter case" argument gets *stronger*, not weaker.

(The interactive editor is a separate matter, and deliberately left as one.
`mason-tool-installer` declares `prettier`, `npm` is now reachable through
`mise`, and `lua/ucw/plugins/mason-tool-installer.lua`'s own comment
predicts what follows: *"the day `npm` is reachable it installs itself — and
markdown starts being reformatted on save, an intended behaviour arriving by
surprise."* Whether that day has actually arrived is **not measured here** —
it needs a real TUI with a real interactive `PATH`, which is the one probe
this document has no reason to run and every reason not to guess at. 6.5 §9
carries it, alongside the same question for `tree-sitter`. Not this phase's,
and not CI's either.)

---

### 1.2 (r3, superseded above) Five cases reach outside the test child — and they do not have to

`tests/test_format.lua:37` computes `REAL_MASON_BIN` from the *driver's*
`stdpath('data')` (the child's is a scratch temp dir) and prepends it to the
child's `PATH` for five cases: `stylua` via `<leader>lf`, `ruff_format`,
`taplo`, `format_on_save` writing a reformatted `.lua` to disk, and the r6
firenvim regression. Phase 6 was right to want real binaries over faked CLI
output; reaching for *this machine's* copy of them is the part that makes
"someone has run mason-tool-installer here" a silent prerequisite of a green
suite, and a bare runner an automatic failure.

**The child can install them itself.** Measured, in a real mini.test child
(which has **no UI attached** — `#nvim_list_uis() == 0`):

```lua
require('lazy').load{plugins={'mason.nvim','mason-tool-installer.nvim'}}
require('mason-tool-installer').setup({ensure_installed={'stylua','ruff','taplo'}})
vim.cmd('MasonToolsInstallSync')
```

* **1.14 s for all three** (1.65 s for `stylua` alone on a colder run), into
  the child's own scratch `<data>/mason`.
* `executable('stylua')` is `1` afterwards **with no `PATH` edit at all** —
  `mason.setup()` already puts `<data>/mason/bin` on the child's `PATH`.
* Paid once per test *file*, not per case: `state.tempdir` is created in
  `pre_once` and every case's `XDG_DATA_HOME` points back at it, which is the
  same reason the 46 plugins are only installed once per file.
* Headless is not the obstacle. What cannot happen without a UI is the
  *automatic* path — `mason-tool-installer` hangs off `VeryLazy`, and
  `tests/test_lsp.lua:88` asserts that as a precondition precisely so the
  suite never starts downloading nine language servers per run. An explicit
  sync install is a different thing, and both statements need to stay true;
  they are in different files with different tempdirs, so they can.

**And absence is testable in the same file**, which matters because "no
formatter installed" is a real state of a real machine, not an accident of
CI. Removing `<data>/mason/bin` from the child's `PATH` restores it exactly,
*after* an install and independently of case order — measured both ways:

| state | buffer | notification |
|---|---|---|
| `stylua` present | `local x=1` → `local x = 1` | none |
| `PATH` stripped | `local x=1` unchanged | 1 × WARN `Formatters unavailable for lua file` |
| markdown (no `prettier` ever) | unchanged | 1 × WARN `Formatters unavailable for markdown file` |

Both directions matter and neither is silent — the missing-formatter case is
a *loud* no-op that does not fall back to `lua_ls` (that is
`lsp_format = 'never'` from Phase 6 §1.1 doing its job). Note the caching
Phase 6 already documented: conform notifies once per filetype per session,
so this is only assertable in a fresh child, which `pre_case` gives.

`prettier` stays uninstallable on purpose even though a GitHub runner has
`npm` and this machine does not: installing it in CI only would make CI the
one place markdown gets formatted — a difference between the two
environments introduced by the thing meant to check they agree. Markdown is
the natural "no formatter exists at all" case, and it stays that way.

### 1.3 Plugin installs are cheap, so caching is a decision to defer

A cold `XDG_DATA_HOME`, full config, `lazy.manage.install()`: **46 plugins,
154 MB, 5.5 s**. Each of the 10 integration files pays that in its own
tempdir, which is most of the 93 s. Rather than design a cache against a
guess about runner network, the first CI run is the measurement (§4).

Two facts fell out of doing this three times: installs honour
`lazy-lock.json` (`git status` stayed clean afterwards — no lockfile churn,
unlike the Phase 6 episode where booting the *embedded* target added a
firenvim pin), which makes a lockfile-drift gate feasible (D6).

### 1.4 `stylua.toml` has never been enforced — and `format_on_save` started enforcing it a day ago

`stylua 2.5.2` (from Mason) against the checked-in `stylua.toml`:

| tree | files differing (r3, 08-07) | files differing (r4, 08-13) | diff lines (r3) |
|---|---|---|---|
| `lua/` | 26 | 26 | 755 |
| `ftplugin/` | 2 | 2 | 29 |
| `tests/` | 16 | **18** | — |
| `after/`, `init.lua` | 0 | 0 | 0 |

**r4: `tests/` grew by two in six days**, and by exactly the mechanism this
section describes. The new files are `tests/test_health.lua` and
`tests/test_treesitter.lua` — both written by Phase 6.5, both agent-authored,
so neither ever passed through a human `:w` and `format_on_save`. That is
the "converts file by file, mixed into whatever commit happened to touch it"
drift, still running, now with a measured rate: the longer D3's one reformat
commit waits, the more of the repo it has to cover.

Two things make this more than cosmetic:

* **The conversion is already happening, invisibly.** Every file *created* by
  Phase 6 (`lua/ucw/plugins/conform.lua`, `ftplugin/{lua,markdown,python,toml}.lua`,
  `lua/ucw/plugins/mason-tool-installer.lua`, `lua/ucw/lsp/actions.lua`) is
  stylua-clean. `ftplugin/tex.lua`, edited in the same commit, is not. The
  difference is not the phase — it is that `format_on_save` (Phase 6) only
  runs when a human `:w`s in Neovim, and agent edits bypass it entirely. So
  the repo converts file by file, mixed into whatever commit happened to
  touch that file.
* **AGENTS.md and the config disagree about `tests/`.** AGENTS.md says
  `lua/**` is 2-space but "existing files under `tests/` use 4-space — match
  the file you are editing". `format_on_save` reads one `stylua.toml` for
  every `.lua` buffer, `tests/` included. The convention loses on the next
  save, silently. Two owners of one rule — the shape of finding this project
  keeps producing.

For the `call_parentheses` question (D4), the cost of each setting, measured
as files differing across `lua/ ftplugin/ after/ init.lua` (~60 files):
`Input` 26, **`NoSingleTable` (current) 28**, `Always` 36, `None` 40,
`NoSingleString` 47.

### 1.5 A 30-second static check finds a live bug and three dead APIs

`lua-language-server --check` (3.18.2-dev, already installed by Mason;
**exit 1 when it finds problems, 0 when clean** — verified both ways). Two
configurations measured over the whole repo:

* **A** — `diagnostics.globals = {vim, MiniIcons, MiniTest, Snacks}`,
  library = `$VIMRUNTIME/lua` + `deps/mini.nvim/lua` → **16 problems**
  (r4, re-measured: **18**, 22 s).
* **B** — same, minus `Snacks`, plus every installed plugin's `lua/` on
  `workspace.library` → **20 problems, 32 s** (r4, re-measured: **22**,
  22 s; 44 library entries = 42 plugin `lua/` dirs out of 47 installed
  plugins, plus `$VIMRUNTIME/lua` and `deps/mini.nvim/lua`), and strictly *more
  accurate*: `Path` (plenary) and `Snacks` resolve to real annotations
  instead of being declared away, so the check can see plugin-level
  deprecations too.

**r4 re-triage (2026-08-13), which the two settings in §1.5b are a
precondition for.** B's set is 22: r3's 20, item for item, plus two from
`tests/test_treesitter.lua:156` (Phase 6.5). Everything r3 called genuinely
wrong is still wrong at the same lines — `neotree/init.lua:62,63`,
`gitsigns.lua:14,23`, `octo.lua:15`, `utils.lua:116`. So **D5's "fixable
here" list needs no revision**; it was measured against a tree that has
since gained two files and lost none of these. The only movement inside the
noise bucket is `treesitter.lua`'s pair, now at **112,113** (Phase 6.5 added
the UI gate above them) and now naming `ParserInfo.tier` /
`InstallInfo.revision`; still the same `missing-fields` on
optional-in-practice fields.

The two new ones are annotation noise of the kind §1.5 already has a bucket
for: `boot_with_attached_ui`'s `---@return integer, integer` versus what
lua_ls infers `vim.rpcrequest` gives back (`nil`). The values are real
integers at runtime — three of Phase 6.5's cases assert on them — so this is
the annotation being narrower than the behaviour, and it takes a suppression
naming that, like its neighbours.

**`lua/ucw/health.lua` is clean** — zero problems. Worth stating rather than
leaving to inference: it is the largest piece of code Phase 6.5 wrote, it
has never been near a static checker, and "the new file is fine" is the only
way a re-triage can report that without someone re-deriving it later.

B's 20 (r3), triaged. **Genuinely wrong today:**

* `lua/ucw/neotree/init.lua:62,63` — `Undefined global 't'`. Both the `s` and
  `S` mappings in the neo-tree window call `t([[<Plug>Lightspeed_...]])`;
  `t` is `utils.t`, imported as a local in `lua/ucw/keys/actions.lua` and
  never here. Pressing either key in the tree throws. A live bug, found
  statically, that no behavioural test covers.
* `lua/ucw/plugins/gitsigns.lua:14,23` — `undo_stage_hunk` and `preview_hunk`
  are both deprecated upstream (→ `stage_hunk()` on staged signs,
  `preview_hunk_inline()`).
* `lua/ucw/plugins/octo.lua:15` — `wk.register{...}`. which-key v3 still
  answers it, as a shim (`M.register` → `M.add(mappings, {version = 1})`,
  `@deprecated`). This is the **last v1-format caller** left after Phase 1's
  conversion, and it sits in the one file Phase 3's P3 audit of that
  conversion never reached.
* `lua/ucw/utils.lua:116` — `nvim_err_writeln`, deprecated in the **C API**.
  `tests/test_deprecations.lua` structurally cannot see this one: it scans
  for `vim.deprecate('name')` calls in Neovim's *Lua* runtime, which is
  exactly the right net for `vim.lsp.get_buffers_by_client_id` and exactly
  the wrong one for `vim.api.*` and for plugin deprecations. The lint gate is
  the complement of that test, not a duplicate of it.

**Annotation noise** (real behaviour, loose upstream types — each would get
an explicit `---@diagnostic disable-next-line` pointing at the review that
verified it, which is cheaper than it sounds because the comment already
exists):

* `lua/ucw/plugins/snacks.lua:88` — `layout = { preview = false }` typed as
  `"main"?`. Phase 5's R1 *proved empirically* this is the spelling that
  works and that `sources.buffers.preview = false` is the one silently
  discarded. Suppress, do not "fix".
* `lua/ucw/plugins/which-key.lua:35` — `Snacks.picker.noice` is registered at
  runtime by noice; no annotation can know it.
* `treesitter.lua:88,89`, `navigator.lua:5` — `missing-fields` on optional-in-
  practice fields.
* `lsp_progress.lua:32`, `keys/actions.lua:49,56`, `ltex_dict.lua:79`,
  `utils.lua:29`, `au.lua:62,63`, `tests/aux/driver_init.lua:15,18` — type
  nits (`rtp:append{}` takes a table in practice, etc.).

### 1.5a How much of the lint config can be checked in (measured against a discriminating probe)

The gate is only worth having if the same rules apply while editing, so the
question is how much of the lua_ls config can be a checked-in file that both
the editor and `just lint` read. Four things measured — each with a probe
that **fails when the library is missing**, because the obvious probes do
not discriminate (a file calling `vim.fn.nonexistent()` reports nothing
either way; the probe that works is `vim.api.nvim_err_writeln` /
`require('which-key').register`, whose *deprecation* warning only appears
when the annotations actually resolve — two dud probes were written and
discarded before this one):

* **Environment variables expand.** `"$VIMRUNTIME/lua"` and
  `"${env:VIMRUNTIME}/lua"` both work in `workspace.library`; a control with
  a bogus literal path reports nothing, so the probe is real. This is what
  lets one file work on this machine and on a runner.
* **An unset variable is harmless** — no error, silently ignored. So a
  library entry can be a placeholder the editor leaves empty and `just lint`
  fills in.
* **Globs do not work.** `"<lazy>/*/lua"` resolves nothing (control: the
  explicit `<lazy>/which-key.nvim/lua` does).
* **Pointing at the lazy root instead of each plugin's `lua/` is weaker, and
  weaker silently**: 16 problems vs 20 over the same tree, 25 s either way.
  It still finds globals like `Snacks` (preload scan) and even the
  `wk.register` deprecation, which is exactly what makes it dangerous — it
  looks like it is working. The four it drops are the ones that need a
  plugin's *module* to resolve (`keys/actions.lua`, `treesitter.lua`).
  Bumping `maxPreload`/`preloadFileSize` does not recover them.

So: the rules can be checked in; the plugin library list cannot be, and
enumerating it is worth the extra step (§3.3).

### 1.5b (r4) Two settings r3 measured with and never wrote down

Building configuration B from §1.5's text alone does **not** reproduce
§1.5's findings. It produces 20 problems — the same *count* r3 reported, by
coincidence, and a different set: measured properly the tree now has 22
(r3's 20 plus two from a Phase 6.5 file), and the naive reproduction drops
three of them and invents one. r3 must have had both settings in the config
it ran; neither reached the page. They were found only because
`octo.lua:15`, a finding r3 named specifically, went missing and was worth
chasing. Both belong in `.luarc.json`/`just lint` explicitly (§3.3, D11).

**1. `$VIMRUNTIME` is not set in a shell.** It is exported by Neovim, to its
own child processes. `just lint` is not one of those: `echo $VIMRUNTIME` in
this repo's shell prints nothing, and §1.5a's own measurement — *"an unset
variable is harmless — no error, silently ignored"* — is exactly what makes
this invisible. The library entry evaporates and the check runs without
Neovim's runtime annotations at all. Measured on configuration A (so the
plugin library is not also in play): **31 problems in 5 files unset, 18
set** — and the 31 contains *fewer* real findings, because a third of it is
`vim.lsp.Client`/`Path`/`undefined-doc-name` noise from types that simply
cannot resolve. Louder and blinder at once, which is the worst combination
for something whose output a human triages.

§1.5a concluded env expansion is "what lets one file work on this machine
and on a runner." It is — but only if something sets the variable, and
nothing does. `just lint` has to supply it: `nvim --headless --clean -c 'echo
$VIMRUNTIME' -c qa` prints `/usr/share/nvim/runtime` on stdout, and `nvim`
is already a hard dependency of every recipe here (§1.6's argument against a
`jq` dependency, reused). Verified: captured cleanly into a shell variable,
and `$RT/lua` exists.

**2. `runtime.pathStrict` defaults to `false`, and this repo self-shadows
under it.** With it off, lua_ls matches `runtime.path`'s `?.lua` against
*every* directory level of the workspace. This repo has
`lua/ucw/plugins/<name>.lua` — one file per plugin, the config's oldest
convention — so `require('snacks')` resolves to **this repo's own snacks
spec table**, not to `snacks.nvim/lua/snacks/init.lua`. Same for
`which-key`, `lualine`, and every other plugin whose spec file is named
after it.

The damage is not that the check gets louder; it gets *differently* loud:

| finding | `pathStrict` off | on |
|---|---|---|
| `octo.lua:15` `wk.register` deprecated | **missing** | present |
| `snacks.lua:88` `layout.preview = false` vs `"main"?` | **missing** | present |
| `lsp_progress.lua:32` `lualine.refresh` type | **missing** | present |
| `snacks.lua:36` "Undefined field `setup`" | **false positive** | absent |
| total | 20 | 22 |

(Both columns measured today, configuration B, `VIMRUNTIME` set in each —
so the only variable is `pathStrict`.)

The false positive is the tell, and it is a nasty one: `require('snacks')`
returned the spec table, which has no `setup`, so the checker complains
about the one line that is unambiguously correct. Meanwhile the three real
findings vanish because a plain table has no annotations to be deprecated
*by*. A reviewer looking at "20 problems, and it caught a deprecation" would
have no reason to look further — which is §5's "a weaker lint config looks
identical to a working one", encountered for real rather than predicted.

Confirmed against the mechanism, not just the numbers: `lua/ucw/plugins/octo.lua`
copied byte-for-byte into a scratch workspace **is** flagged; the same file
checked in place is not. `maxPreload`/`preloadFileSize` are not involved
(bumped to 50000/5000: still 20, exactly as r3 found for a different
question).

**Consequence for `runtime.path`.** Turning `pathStrict` on breaks the other
direction — with the default `["?.lua", "?/init.lua"]`, `require('ucw.utils')`
resolves to nothing, because this config's modules live under `lua/`, and an
unresolvable `require` is silent (`any`, no diagnostic). Adding
`"lua/?.lua"`, `"lua/?/init.lua"` restores it. Measured: **identical 22
findings either way today, 30 s instead of 22 s**. It goes in regardless —
"identical today" is not "equivalent", which is the same argument §1.5a used
to reject the single-directory library shortcut, and internal cross-module
resolution is what makes the *editor* half of D9 worth anything.

### 1.6 `just deps` is the last unpinned dependency — and the pin already exists

`justfile`'s `deps` recipe clones `mini.nvim` at whatever `origin/main` is
that day, and `update=true` hard-resets to it. It is the only input to a test
run that is not pinned now that `lazy-lock.json` exists.

It does not need a *new* pin, because `lazy-lock.json` already carries one:
`"mini.nvim": { "branch": "main", "commit": "946ae64e..." }` — the runtime
copy lazy.nvim installs for editing features. That is a physically separate
checkout from `deps/mini.nvim` (the test harness), and deliberately so, but
there is no reason for them to be different *revisions*.

Measured, so the recipe can be written against facts rather than hope:

* GitHub serves a shallow fetch of a bare SHA — `git clone --depth 1
  --filter=blob:none`, then `git fetch --depth 1 origin <sha>` + `git
  checkout <sha>`: **2 s + 2 s**, and `lua/mini/test.lua` is there.
* `jq` is not needed: `nvim` is already a hard dependency of every recipe
  here, and `vim.json.decode` reads the lockfile.
* Today the two happen to be **the same commit** (`deps/mini.nvim` HEAD ==
  `946ae64`). So this change fixes no current drift; it removes the way
  drift arrives — which is worth saying plainly, because a change that is a
  no-op the day it lands is easy to mis-sell.

The coupling this introduces is real and one-directional: bumping the
runtime `mini.nvim` in `lazy-lock.json` now also moves the test harness.
That is the point (one pin, and the harness tracks something the config
actually uses), but it means an unrelated plugin update can change
`mini.test`'s own behaviour. The recipe must therefore **fail loudly** if
the lockfile has no `mini.nvim` entry, rather than quietly falling back to
`origin/main` — a silent fallback here would restore exactly the
unpinnedness being removed.

### 1.7 Publishing is mechanically unblocked

`gh auth status` reports token scopes `gist, read:org, repo, **workflow**`,
so a workflow file can be pushed over the https remote (the configured push
URL is ssh, which is not usable here — see the standing note about explicit
https URLs). The repo is public, Actions is enabled, `workflows` count is 0.
`.git` is a yadm gitdir pointer file, which affects nothing: the runner does
an ordinary `actions/checkout`. The 24 commits to publish carry one author
identity (`Aetf <aetf@unlimited-code.works>`); a grep for machine-private
strings across tracked files finds only two `/home/aetf/...` paths inside
pasted error output in `docs/`, and the username is already the account name.

## 2. Decisions (answered 2026-08-07; D2/D5/D8 revisited, D11/D12 added 2026-08-13, D13 added 2026-08-13)

* **D1 — Publish: yes, branch *and* PR.** `modernize-2026` is pushed to
  `origin` and a PR opened against `main`, so both trigger paths (`push`
  and `pull_request`) are exercised from the first run rather than
  discovered later. The merge itself still waits for Phase 10; the PR
  exists to run CI, not to be merged now.
* **D2 — Matrix: `stable` + `nightly` only.** No `v0.12.3` leg: a pin that
  has to be hand-bumped whenever Arch moves is maintenance that buys a
  narrowing window (0.12.3 → 0.12.4 is one patch release). The consequence
  is explicit and recorded as a risk in §5: **the version this machine
  actually runs is not covered by CI**, so a 0.12.3-only regression is
  found by using the editor, not by CI.
  **r4: the consequence closed by itself and the decision is now free.**
  `pacman -Q neovim` reports `neovim 0.12.4-1` and `nvim --version` agrees —
  Arch moved, and this machine now runs what `stable` resolves to. §5 said
  the thing to watch for was the window *not* closing; it closed, in six
  days, which is the outcome D2 was betting on. **r5: the remaining check is
  now done, not deferred.** `neovim/neovim`'s `stable` GitHub release is a
  rolling tag rather than a snapshot — `GET
  /repos/neovim/neovim/releases/tags/stable` returns "NVIM v0.12.4" today —
  and `rhysd/action-setup-vim`'s README documents installing from that same
  tag for `version: stable`. So the two legs are `v0.12.4` and `nightly` in
  fact, verified before the workflow file exists rather than after.
* **D3 — stylua: adopt in full.** One reformat commit over the whole repo
  including `tests/`; the 4-space convention leaves AGENTS.md;
  `.git-blame-ignore-revs` added; CI runs `stylua --check`.
* **D4 — `call_parentheses` stays `NoSingleTable`** (reversed in r3, user).
  The r2 argument for `Always` (README pastes survive a `:w` unchanged) is
  worth less than one consistent house style, and a paste that gets
  reformatted on save is not friction — it is the formatter doing its job.
  28 files rather than 36.
* **D5 — Lint: configuration B at `--checklevel=Warning`**, fix what this
  phase can fix, record the rest (§7). "Fixable here" is the three that are
  local, mechanical, and have no keymap semantics: `neotree/init.lua`'s
  undefined `t`, the two gitsigns deprecations, and `nvim_err_writeln`.
  `octo.lua`'s `wk.register` is not: the whole file is still in which-key's
  v1 nested-table shape, and rewriting a keymap spec is Phase 8's subject —
  it gets a suppression comment that names Phase 8, and a §7 entry, rather
  than a stopgap edit that Phase 8 would then redo.
* **D6 — Lockfile-drift gate: yes** (default taken; measured feasible in
  §1.3 and costs one step). After a clean install, `git diff --exit-code
  lazy-lock.json`.
* **D7 — README badge: yes** (default taken).
* **D8 (r4) — superseded by what Phase 6.5 built; only its unbuilt half
  remains.** The principle stands untouched: formatter availability is
  behaviour, not setup, and **both of its states are expected behaviour**.
  The mechanism is not the one r3 chose. `mise.toml` pins the three
  formatters, `just test` runs under `mise exec --`, the child inherits
  them — no in-child Mason install, no `REAL_MASON_BIN`, both already gone
  (§1.2). What this phase still owes is the half that was decided and never
  written: the **absent** state asserting its WARN notification, not just
  the blocked-fallback property (§3.4). r3's own reasoning for why it is a
  case and not a `MiniTest.skip()` carries over verbatim.
* **D8 (r3, superseded) — the suite installs its own formatters.** Formatter
  availability is not CI setup and not a host prerequisite: it is behaviour,
  and **both of its states are expected behaviour**. `tests/test_format.lua`
  installs `stylua`/`ruff`/`taplo` into the child's own scratch Mason
  (1.14 s, §1.2), covers the present case against those real binaries, and
  covers the absent case by stripping `<data>/mason/bin` back off `PATH`.
  `REAL_MASON_BIN` and the proposed `just tools` recipe both disappear —
  the r2 design would have moved a host dependency into a CI step instead of
  removing it.
* **D9 — the lint config lives in the repo** (r3, user), so editing this
  config gets the same diagnostics without waiting for a CI run. `.luarc.json`
  is checked in and holds every *rule*; only `workspace.library` is
  environment-derived, and each environment supplies it its own way (§3.3).
* **D10 — `just deps` pins to `lazy-lock.json`** (r3, user). The lockfile's
  `mini.nvim` commit is the pin for `deps/mini.nvim` too, even though the two
  checkouts are deliberately separate installs (§1.6).
* **D11 (r4, from §1.5b) — `.luarc.json` carries `runtime.pathStrict = true`
  and an explicit `runtime.path`, and `just lint` exports `VIMRUNTIME`.**
  Neither is a tuning knob; each is the difference between the gate §1.5
  measured and a gate that silently checks something else. Both halves of
  the `.luarc.json` side are checked in, so the editor gets them too — which
  is D9's whole ask, and note the two environments fail *oppositely* here:
  the editor has `$VIMRUNTIME` set and `pathStrict` unset, `just lint` the
  reverse. One file plus one exported variable covers both. This also
  qualifies D9's "only `workspace.library` is environment-derived": the
  library *list* is, and so is the expansion of `$VIMRUNTIME` within it.
* **D12 (r4) — `mise` is part of the bare-runner contract** (§1.2).
  `checkout` + `nvim` + `just` + `mise`, then `just deps`. r3's §3.2 sketch
  predates `mise.toml` and has no such step; without it every job fails on
  its first recipe. The `lint` job needs `nvim` too, for D11's reason.
* **D13 (r5, user) — `jdx/mise-action`'s own `version:` input gets pinned.**
  Left unspecified it defaults to `latest`, which means the mise binary
  running in CI drifts independently of everything mise.toml pins *through*
  it. That is not a hypothetical: `mise.toml`'s own header comment stakes
  the whole no-`mise-trust`-needed argument (D8's "`just deps` is one
  command" claim, §1.2) on a specific measurement — *"measured on mise
  2026.7.11"* — and this machine is still on exactly that version
  (`mise --version`, checked 2026-08-13). An unpinned action is the same gap
  that got `JohnnyMorganz/stylua-action` deleted from §3.2 in favour of
  `mise.toml`'s pin: a second, independently-drifting copy of a version this
  design already measured once. Pinned to `2026.7.11` in all three jobs'
  `mise-action` steps (§3.2); bumping it later is one line, same as bumping
  any other entry in `mise.toml`.

## 3. Proposal (as decided)

### 3.1 One mechanism, two callers

Every gate is a `just` recipe; the workflow only ever calls `just`. That is
the same rule the rest of this config follows (`just tui` wrapping
`tui-drive.sh`), and it means "reproduce CI locally" is copy-pasting one
line rather than reading YAML.

New recipes:

* `just lint` — runs `lua-language-server --check` (§3.3). **r4: all three
  recipes already exist** (`lint`, `fmt`, `fmt-check`), added by Phase 6.5,
  and all three already resolve their binary through `mise exec --` rather
  than r3's "from Mason's bin dir" — that delta from 6.5 §8 is done. What
  `just lint` still needs is not a binary but an environment and a config:
  `VIMRUNTIME` exported from `nvim` itself, and the generated library list
  (§3.3, D11).
* `just fmt` / `just fmt-check` — `stylua .` and `stylua --check .`.

There is deliberately **no `just tools`**: r3 put formatter installation
inside the suite; `mise.toml` + `just deps` now does it one level out, and
in both designs the point is the same — "the tools are there" is never an
undocumented precondition. `just deps` is the one recipe you run
deliberately, and it is the whole setup story (6.5 §2.3a).

`just deps` stops tracking `origin/main` and checks out the `mini.nvim`
commit named in `lazy-lock.json` (§1.6), read with `vim.json.decode` rather
than a new `jq` dependency, and **erroring** if that entry is absent.

### 3.2 `.github/workflows/ci.yml`

```yaml
name: CI
on:
  push:
  pull_request:
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        neovim: [stable, nightly]              # D2
    runs-on: ubuntu-latest
    timeout-minutes: 20
    continue-on-error: ${{ matrix.neovim == 'nightly' }}
    steps:
      - uses: actions/checkout@v7
      - uses: rhysd/action-setup-vim@v1        # v1.6.1
        with: { neovim: true, version: '${{ matrix.neovim }}' }
      - uses: extractions/setup-just@v4
      - uses: jdx/mise-action@v2               # D12 (r4)
        with: { version: '2026.7.11' }         # D13 (r5)
      - run: just deps
      - run: just ci
      - run: git diff --exit-code lazy-lock.json    # D6
  lint:
    runs-on: ubuntu-latest
    steps: [ checkout, setup-just, setup-neovim, "mise-action@2026.7.11", just lint ]     # D5, D11, D12, D13
  format:
    runs-on: ubuntu-latest
    steps: [ checkout, setup-just, "mise-action@2026.7.11", just fmt-check ]              # D3, D12, D13
```

**r4 changes three things in that sketch, r5 pins one more.** `mise` is set
up in every job (D12) — without it no recipe resolves its binary. The
`format` job drops `JohnnyMorganz/stylua-action` for `just fmt-check`, which
restores §3.1's "the workflow only calls `just`" invariant and *deletes* the
stylua-skew risk in §5 instead of mitigating it: `mise.toml` pins
`stylua = "2.5.2"`, so CI and this machine run the same binary by
construction (6.5 §8). And the `lint` job needs **Neovim installed**, which
is not obvious and is easy to drop as redundant on a job that runs no
tests: `just lint` gets `VIMRUNTIME` by asking `nvim` for it (§1.5b, D11).
Without `nvim` on that runner the recipe does not fail — it produces the
weaker check described in §1.5b, in CI only, where nobody would see the
difference. **r5**: `mise-action`'s own `version:` is pinned to `2026.7.11`
in all three jobs (D13) — the same by-construction reasoning that just
deleted `stylua-action`'s independent pin applies one layer down, to the
tool that resolves `stylua` in the first place.

The lockfile-drift step lives on the `test` job because that job is the one
that has already done a full install; on the `stable` leg only, so a nightly
that resolves something differently cannot fail it.

`lint` and `format` are separate jobs, not extra steps on the test job: they
are version-independent, they finish in seconds, and keeping them off the
matrix means a formatting nit does not report three identical failures.

`stylua-action` needs a pinned version matching this machine's Mason copy
(2.5.2 today) or the two disagree about output — see §5.

### 3.3 `.luarc.json`, and who owns `diagnostics.globals`

`.luarc.json` is checked in at the repo root, so the editor's own `lua_ls`
reads it for this workspace too — the gate and the squiggles agree by
construction rather than by discipline.

The seam to be careful about: `after/lsp/lua_ls.lua` already declares
`diagnostics.globals = { 'vim', 'MiniIcons' }`, and that file is *global*
config (it applies to every Lua project the user opens), while `.luarc.json`
is *this repo only*. They are different scopes, so neither can simply own
the other — but they can drift. Proposal: a unit test asserting the
`.luarc.json` globals are a superset of `after/lsp/lua_ls.lua`'s, which is
the cheap version of the "one writer" rule Phase 3 settled on for
`client.settings`.

**Every rule lives in `.luarc.json`** — `runtime`, `diagnostics`,
`ignoreDir`, and the two libraries that are environment-independent because
`$VIMRUNTIME` expands (§1.5a) and `deps/mini.nvim/lua` is in-tree:

```json
"runtime": {
  "version": "LuaJIT",
  "pathStrict": true,
  "path": ["?.lua", "?/init.lua", "lua/?.lua", "lua/?/init.lua"]
},
"workspace": { "library": ["$VIMRUNTIME/lua", "deps/mini.nvim/lua"], ... }
```

**r4: the `runtime` block above is not boilerplate, it is D11**, and §1.5b
is why each line is there. `pathStrict: true` stops `require('snacks')` from
resolving to this repo's own `lua/ucw/plugins/snacks.lua`; the explicit
`path` puts back the internal `require('ucw.*')` resolution that turning it
on would otherwise cost. Both apply to the editor as well, which is the
point of checking the file in.

`$VIMRUNTIME` is in the library list because it expands (§1.5a) — but only
where it is set, which is inside Neovim and not in `just lint`'s shell
(§1.5b). The recipe therefore exports it, from `nvim` itself:

```sh
VIMRUNTIME="$(nvim --headless --clean -c 'echo $VIMRUNTIME' -c qa)"
```

No second source of truth: whichever `nvim` is running the tests is the one
whose runtime gets checked against.

The one thing that cannot be checked in is the **plugin** library list:
globs do not work, and the single-directory shortcut is silently weaker
(§1.5a). Each environment supplies it its own way, and neither is a second
config:

* **The editor**: `lazydev.nvim` already adds a plugin's `lua/` on demand,
  which is the reason `after/lsp/lua_ls.lua` deliberately stopped handing
  lua_ls `nvim_get_runtime_file('', true)` up front. So the editor gets
  §1.5's configuration-B strength *and* keeps the indexing cost Phase 3
  removed — putting the plugin set into `.luarc.json` would undo that
  decision for the editor in order to serve the CLI.
* **`just lint`**: enumerates `<lazy root>/*/lua` and writes a gitignored
  `.luarc.lint.json`. That file is a *derived artifact*, not a config: the
  recipe loads `.luarc.json` and appends to exactly one key, so no rule can
  come to live in it by construction rather than by promise.

What this buys, concretely, is D9's ask: a warning the gate would fail on
is already on screen while editing the file that causes it.

### 3.4 (r4) `tests/test_format.lua` owns formatter availability — one half left to build

Two of r3's three bullets below are **already true**, built by Phase 6.5 by
another route (§1.2). What is left is the third.

* **install** — *dropped, not deferred.* `mise.toml` + `just deps` is the
  installation, and its failure is loud and immediate (no binary, every
  real-CLI case red). r3 wanted a case because "mason can install this
  config's formatters" was believed rather than tested; that sentence is no
  longer about anything this suite depends on.
* **present** — the four `'real CLI formatters'` cases, already reaching
  real, version-pinned binaries with no setup step. Unchanged.
* **absent — the piece this phase builds.** `no_formatters_on_path()`
  already exists and is already used, but only inside `'lsp_format
  blocking'`, for the *fallback* property. The notification half of D8 gets
  its own group next to it, asserting both halves together for each state:
  buffer unchanged **and** exactly one WARN `Formatters unavailable for <ft>
  file`. Two filetypes: one with `PATH` stripped (a machine where nothing is
  installed), and **markdown**, which needs no stripping — it has no
  formatter in a test child on any machine, guaranteed by
  `cond = is_full_ui` rather than by `npm` being absent (§1.2).

Both assertions in one case on purpose, the same reason Phase 6's r6
regression put its two halves together: "the buffer is unchanged" alone
passes just as well when conform never ran at all, and a WARN alone says
nothing about what happened to the buffer.

Watch conform's once-per-filetype-per-session notification cache
(`has_notified_ft_no_formatters`, Phase 6): the count is only assertable in
a fresh child, which `pre_case` gives, and "exactly one" is the assertion
that would catch it regressing to zero on a second format in the same case.

Reverse-verified per Phase 4's F5 rule, in the direction that actually
discriminates: with the WARN suppressed or conform's `notify_no_formatters`
disabled, the new cases must go red *for the notification*, not for the
buffer — otherwise they are the buffer assertion again under a new name.

No skips and no `if executable(...) then`: a `MiniTest.skip()` is a green
case, which is the dud-test pattern Phase 4's F5 rule exists to prevent —
and here it would be worse than usual, because the state it would skip on
*is* one of the two behaviours being specified.

The install case makes ordering matter within the file, so it must not be
expressed as ordering: the absent cases strip `PATH` explicitly rather than
relying on running before the install (measured to work in either order,
§1.2). The one genuinely order-dependent thing — `state.tempdir` being
shared across cases in a file — is what makes the install cost 1.14 s once
instead of per case.

### 3.5 Commit order

1. `just deps` pinned to `lazy-lock.json`'s `mini.nvim` (D10; a no-op today,
   §1.6, so it lands alone and stays readable as one).
2. The reformat commit — stylua output only, nothing else, so it reads as
   "no semantic change"; `.git-blame-ignore-revs` in the same commit.
   `stylua.toml` itself is untouched (D4).
3. `.luarc.json` (rules + D11's `runtime` block) + `just lint`'s
   `VIMRUNTIME` export and generated library list + the three lint fixes
   (D5) + the suppressions, each naming what verified the behaviour it is
   suppressing — including the two new `test_treesitter.lua:156` ones (§1.5).
4. `tests/test_format.lua`: the absent-state notification group (D8's
   unbuilt half, §3.4). `REAL_MASON_BIN` and the install case are **not**
   here — the former is already deleted, the latter is dropped.
5. The workflow file itself, last, so the first run exercises finished gates.
6. AGENTS.md + README: "No CI yet" and the 4-space convention both stop
   being true; badge (D7).
7. Push, then open the PR (D1). Verification (§4) happens against the real
   runner from here on.

### 3.6 Non-goals

Dependabot/Renovate for `lazy-lock.json`; screenshot goldens; coverage;
release automation; pre-commit hooks (the gates are `just` recipes; wiring
them into a hook is a personal-workflow choice, not a repo one); a
self-hosted runner.

## 4. Verification plan

Per the Phase 4 F5 rule, every gate is verified by **breaking it on
purpose** and confirming the *predicted* leg goes red for the *predicted*
reason, then reverting:

* a deliberately failing `eq` → `test` job red, both legs. (Already
  half-done locally: exit code 1 confirmed, §1.1. `lua-language-server
  --check` likewise re-confirmed exit 1 with problems, r4.)
* **`just lint` against a known finding, twice** (r4, §1.5b): unset
  `VIMRUNTIME` and confirm the count changes (18 → 31 with configuration A's
  library set), and drop `pathStrict` and confirm `octo.lua:15` disappears.
  These are the two ways the gate degrades without failing, and each is
  cheap to re-check whenever `.luarc.json` or the recipe changes.
* unformat one file → `format` job red, `test` green.
* re-introduce the `t` call → `lint` red; and, before the fixes land,
  confirm the gate is red for exactly the findings §1.5 lists and no
  others — a suppression that quietly hides a fourth thing is the failure
  mode here.
* remove a `lazy-lock.json` entry → drift gate red (D6).
* **the absent-formatter cases, reverse-verified the hard way**: drop the
  `PATH` strip and they must go *red*, because a case that passes whether or
  not the formatter is there is asserting nothing. **r4 adds the
  discriminating direction**: suppress the notification only, leaving the
  formatter genuinely absent, and the new cases must still go red — for the
  WARN, not for the buffer (§3.4). ~~Same in the other direction: skip the
  install and the present cases must go red.~~ There is no install step to
  skip; the equivalent is running outside `mise exec`, which Phase 6.5
  already measured as 6 red cases.
* `just deps` against a `lazy-lock.json` with the `mini.nvim` entry removed
  → recipe errors, does not silently clone `origin/main` (§1.6).
* nightly leg made to fail on purpose → workflow still reports success.

Then the part that cannot be done locally: **read the first real run's
timings** (per-job wall clock, how much of it is the 10 cold plugin
installs) and decide caching from that number rather than from a guess
(§1.3). And run the matrix at least twice on an unchanged tree, because
"green once" is not a signal in this project (Phase 3, P7).

## 5. Risks

* **Publishing is one-way.** 24 commits and 10 design documents become
  public and indexed. §1.7 says the content looks clean; the pre-push check
  should still be done deliberately, not asserted from a grep.
* ~~**The version this machine runs is not in the matrix** (D2). Arch
  `extra` is on `neovim 0.12.3-1` and `stable` is `v0.12.4`.~~ **Closed
  (r4, 2026-08-13): Arch moved to `neovim 0.12.4-1`**, six days after this
  risk was written, which is the outcome it was waiting on. Kept struck
  through rather than deleted because the *shape* recurs — the next time
  Arch lags a release, this is the entry that says what to do (add a pinned
  leg at Phase 10 if it is a minor version behind).
* ~~**`stylua` version skew.** Mason's copy here is 2.5.2; `stylua-action`
  pins separately.~~ **Deleted, not mitigated (r4).** `mise.toml` pins
  `stylua = "2.5.2"` and the `format` job runs `just fmt-check` under `mise
  exec`, so there is no second pin to skew against (6.5 §8). A bump is now
  one line in `mise.toml` plus the reformat commit it implies.
* **Rare test flake meets a slower machine.** The `test_boot` hit-enter
  intermittent did not appear in four local runs, but a runner is slower and
  differently scheduled. If it shows up: root-cause the boot handshake in
  `tests/aux/lua/helpers.lua`, do **not** add a retry or a sleep — the same
  standing rule that produced the current RPC-round-trip drain in the first
  place.
* ~~**The suite now depends on Mason's registry, not just on GitHub.** D8
  moves a formatter download into every `just all`.~~ **Never materialised
  (r4)**: no formatter download happens in the suite at all. `mise` resolves
  the pins once, in `just deps`. The second upstream is `mise`'s registry
  rather than Mason's, and it is hit at setup time rather than per run.
* **A weaker lint config looks identical to a working one.** §1.5a's
  single-directory shortcut finds 16 of 20 problems and says nothing about
  the four. Whatever `just lint` generates has to be checked against a known
  finding, not against "it ran and exited 0" — the reverse-verification in
  §4 covers this once, and it is worth re-checking whenever the library
  construction changes. **r4: this was written as a hypothetical, and it has
  since happened to this document — twice, from two mechanisms neither of
  which is the library list** (§1.5b): `$VIMRUNTIME` unset outside Neovim,
  and `runtime.pathStrict` defaulting to false in a repo whose files are
  named after the plugins they configure. Both are now explicit (D11), but
  naming two instances does not fix the mode — an `nvim`-less `lint` job
  reproduces the first exactly. So the mitigation is the general one, and it
  is the only part of this entry worth carrying: **check the gate against a
  known finding, never against "it ran and exited 0"** (§4 now does this
  twice, deliberately). Three predicted instances, two observed, one of them
  in the very text that predicted it.
* **`nightly` noise.** `continue-on-error` keeps it advisory, but an
  advisory leg that is red for three months is a leg nobody reads. If it
  stays red for a reason that is not actionable, delete it rather than
  ignore it.
* **CI green ≠ this machine green.** ~~CI has `npm` and no `tree-sitter`
  CLI; this machine has neither.~~ **r4: this machine has both** — mise
  carries `node` 25.9.0 and `tree-sitter` 0.26.11, and since the `PATH` fix
  (yadm `947bf33`) they are actually reachable. Formatters do not differ:
  `mise.toml` pins the same three versions for both environments. Markdown
  having no formatter no longer rests on `npm` being absent either — in a
  test child it is `cond = is_full_ui` that guarantees it, which holds in
  both environments by construction (§1.2). What is left of this risk is
  narrower and more honest than r3's version: the two environments agree on
  everything the suite touches, and the remaining differences (the
  interactive editor's now-reachable `prettier` and `tree-sitter`) are
  outside CI's reach *and* outside its notice — 6.5 §9 carries them.

## 6. Observed, out of scope

* ~~The blink.cmp completion popup that appears in a freshly opened `.lua`
  buffer with no keypress~~ - **root-caused and fixed (r11, §9.9)**. It was not
  about `.lua` files: using the *cmdline* to open anything is the trigger, and
  the cause is an upstream race between `vim.on_key`'s mode check and the
  `vim.schedule` that acts on it.

## 7. Carried forward (D5's "record the rest")

Things this phase's lint gate found and deliberately does not fix, each
suppressed with a comment that says so, so the gate stays green without the
knowledge leaking out of the repo:

* **`lua/ucw/plugins/octo.lua` — which-key v1.** `wk.register{...}` plus the
  whole nested-table spec below it. Works today through a shim
  (`M.register` → `M.add(mappings, {version = 1})`); it is the last v1
  caller left after Phase 1's conversion, in the one file Phase 3's P3
  audit of that conversion never opened. **Phase 8** (keymap registration)
  owns the rewrite. Worth knowing when it happens: P3's finding was that
  the v1→v3 conversion silently moved right-hand sides into `desc`, and
  `tests/test_keys.lua` now asserts no which-key entry's `desc` looks like
  an rhs — so this file gets that check for free the moment it converts.
* **Annotation-level suppressions** in `snacks.lua` (`layout.preview =
  false`, proven correct by Phase 5's R1), `which-key.lua`
  (`Snacks.picker.noice`, a source noice registers at runtime),
  `treesitter.lua` / `navigator.lua` (`missing-fields` on
  optional-in-practice fields), and the type nits in `lsp_progress.lua`,
  `keys/actions.lua`, `ltex_dict.lua`, `utils.lua:29`, `au.lua`,
  `tests/aux/driver_init.lua`. These are upstream annotations being
  narrower than upstream behaviour; each suppression names the evidence.
* ~~**A pinned `v0.12.3` leg**, if Arch has not caught up by Phase 10~~ —
  it did (r4, §5). Nothing carried.
* ~~**Cache design for the 10 cold plugin installs**, deferred to the first
  run's real numbers~~ — measured on the real runner and **dropped**: the whole
  `test` job is ~2.5 min including all ten (r9, §9.7).
* **`README.md` is still the pre-migration document** (r4). It opens by
  describing the systemd-style dependency engine Phase 1 deleted. D7 adds a
  badge to it, which does not make it less wrong; the rewrite belongs with
  `docs/architecture.md` in Phase 10, exactly the call Phase 6.5's
  acceptance review made about that file. Worth saying out loud so the badge
  commit is not mistaken for having looked at the page it lands on.
* **The two `tests/test_treesitter.lua:156` annotation suppressions** (r4,
  §1.5) — new members of the §7 annotation list above, same reasoning:
  `vim.rpcrequest`'s inferred return type is looser than what the three
  cases using it assert.
* **(r10) neo-tree on Neovim 0.13.** `BufModifiedSet` is removed in 0.13 and
  neo-tree's `v2.x` branch still registers it, so its event setup raises `E216`
  and the error is notified on every first open of the tree. Fixed upstream on
  `main` only; this config pins `branch = 'v2.x'` and is already at its tip, so
  the resolution is a branch decision rather than a version bump. Not urgent -
  0.13 is not released - and `tests/test_neotree.lua` fails by name the day it
  becomes urgent. See §9.8.
* **(r7) `gitsigns.undo_stage_hunk`.** Joins `toggle_deleted` directly below,
  for the identical reason and after the identical measurement — r6 shipped it
  as a "mechanical" replacement and it was not one. `undo_stage_hunk()` pops a
  session-local LIFO and ignores the cursor; `stage_hunk()` acts on the hunk at
  the cursor and only inverts when there is no unstaged hunk there. See §9/R2.
* **(r6) `gitsigns.toggle_deleted`.** Deprecated in favour of
  `preview_hunk_inline()`, and left alone rather than replaced: the two are
  different features (a persistent `show_deleted` toggle versus a one-shot
  inline preview of the hunk under the cursor), so swapping them changes what
  `:GitsignsToggleDeleted` does. That is a behaviour decision, not a lint fix.
  §1.5 had this finding recorded as `preview_hunk`, which is not deprecated at
  all — see §8.1.

## 8. (r6) As built

Seven commits, in §3.5's order. `2529804` `just deps` pin (and this document);
`22789b5` the reformat; `645857d` `.git-blame-ignore-revs`; `0c6ff07` the lint
gate; `0bcf3a5` the absent-formatter cases; `9b7a623` the workflow; `52dc6a5`
the docs. 145 cases green twice, `just lint` and `just fmt-check` both green.

### 8.1 Four statements above are wrong

Each was caught by something that refused to proceed, not by a red run on
GitHub — which is what §5's mitigation ("check the gate against a known
finding, never against *it ran and exited 0*") is for.

**`$VIMRUNTIME` cannot be captured with `:echo`** (§1.5b, §3.3). Headless
`:echo` writes to **stderr**, so `VIMRUNTIME="$(nvim --headless --clean -c
'echo $VIMRUNTIME' -c qa)"` — the exact line §3.3 proposes — assigns the empty
string. An unset library entry is silently ignored (§1.5a measured that and
called it a feature), so this would have produced a lint job that ran, exited
0 on a good day, and checked the repo with none of Neovim's annotations: **36
problems instead of 22, and fewer of them real.** The recipe uses `-c 'lua
io.write(vim.env.VIMRUNTIME or "")'`, and refuses to run when the result is
empty or has no `lua/` under it. It refused on the first invocation, which is
the only reason this is a footnote rather than §9.

**`pathStrict` is not the variable §1.5b thought it was.** Measured across the
matrix (configuration B, `VIMRUNTIME` set, only `runtime` varying):

| `runtime.path` | `pathStrict` | result |
|---|---|---|
| lua_ls default (key absent) | absent | 22 |
| lua_ls default | `false` | 22 |
| lua_ls default | `true` | 22 |
| `["lua/?.lua", …, "?.lua", …]` (as built) | `true` | 22 |
| `["lua/?.lua", …, "?.lua", …]` (as built) | `false` | 22 |
| `["?.lua", …, "lua/?.lua", …]` (§3.3's order) | `true` | 22 |
| `["?.lua", …, "lua/?.lua", …]` (§3.3's order) | `false` | **20 + 1 false positive** |

So the self-shadowing §1.5b describes is real, and it needs **both** an
explicit `runtime.path` carrying `lua/?.lua` *and* `pathStrict` off. Neither
alone does anything. §1.5b measured its "off" column with half of D11's own fix
already applied and attributed the whole effect to the other half.

The conclusion D11 reached is unchanged and is now better founded: **the two
halves are not independent, and `runtime.path` without `pathStrict` is worse
than neither.** That is a sharper claim than "turn `pathStrict` on", and it is
the one `tests/test_luarc.lua` asserts. The built order puts `lua/?.lua` first
(matching `after/lsp/lua_ls.lua`, so the two files read the same), which
happens to be immune even without `pathStrict` — kept on regardless, because
"immune today" is not "equivalent", the same argument §1.5b used for adding
`runtime.path` in the first place.

**§1.5 misidentified the second gitsigns deprecation.** It is not
`preview_hunk` — that one is fine — but `toggle_deleted`, whose
`@deprecated` annotation sits directly above it in `gitsigns/actions.lua:231`
and points at `preview_hunk_inline()`. That matters for D5's triage, not just
for accuracy: `undo_stage_hunk → stage_hunk` really is mechanical (upstream
unified the two operations; same surface, same intent), but `toggle_deleted →
preview_hunk_inline` is **not** — one flips a persistent per-buffer config, the
other previews a single hunk once. Swapping them is a behaviour decision, so it
is suppressed and carried in §7 rather than "fixed". D5's fixable list is
therefore three items, not four.

**`jdx/mise-action` is on `@v4`.** D13 pins the action's `version:` input and
r5 wrote `@v2` for the action itself, which is three majors stale. All four
actions were checked against the API before the file was written:
`actions/checkout` v7.0.1, `rhysd/action-setup-vim` v1.6.1,
`extractions/setup-just` v4, `jdx/mise-action` v4.2.5. D2's `stable` question
is closed at the commit level rather than by release title: `stable` is a
lightweight tag on `68ea43cd`, and the annotated `v0.12.4` tag dereferences to
the same commit.

### 8.2 The gap: the `lint` job had no plugins

§3.2's `lint` job is `checkout, setup-just, setup-neovim, mise-action, just
lint`. Nothing there installs the plugins, and §1.5a already measured what a
missing plugin library costs: 16 findings instead of 22, silently. This is
exactly the hazard §3.2 names one paragraph earlier for `nvim` — *"the recipe
does not fail, it produces the weaker check, in CI only, where nobody would see
the difference"* — applied to the other half of the same config and missed.

Built: a `just plugins` recipe (`nvim --headless '+Lazy! install' +qa`; `install`
rather than `restore`, so running a linter never drags an already-installed
plugin back to the lockfile), `lint` depends on it, and
`scripts/luarc-lint-config.lua` exits 1 with the recipe name when the plugin
root is absent or has no `lua/` directories. Both refusal paths verified.

### 8.3 What was verified, and one verification that was a dud

Per §4, every gate was broken on purpose:

* `just deps` — fresh clone lands on the pin (4.5 s); an existing checkout at a
  different commit converges by single-SHA fetch (0.9 s, no unshallow); a
  lockfile with the entry removed exits 1 rather than cloning `origin/main`.
* `just lint` — dropping the `t` import makes it red for exactly those two
  lines and exit 1; green is exit 0. `VIMRUNTIME` unset: 22 → 36. `pathStrict`
  dropped from §3.3's path order: `octo.lua:15`, `snacks.lua:88` and
  `lsp_progress.lua:32` disappear and `snacks.lua:36` appears.
* `.luarc.json` **in the editor**, which is D9's entire justification and is
  not observable from the CLI: in a real TUI, `tests/test_luarc.lua` reports
  zero diagnostics with the file present and `Undefined global MiniTest` twice
  with it moved aside. `MiniTest` is in `.luarc.json`'s globals and not in
  `after/lsp/lua_ls.lua`'s, which is what makes the probe discriminate.
* `tests/test_luarc.lua` — each case red for its own reason when the setting it
  guards is removed.
* The absent-formatter cases — red for the *notification* (not the buffer) with
  `notify_no_formatters = false` and the formatter still genuinely absent.
* Bare-runner shape — lazy bootstraps itself and installs 46 plugins into an
  empty data dir in 9.6 s, the generator finds 41 plugin `lua/` dirs, the check
  is green, and `lazy-lock.json` does not move (which also de-risks D6).

**The dud is worth more than any of them.** The first bare-runner simulation
was `XDG_DATA_HOME=/tmp/scratch just lint`. It printed a plausible number of
library entries and a green check in 30 s, and it was a completely ordinary run
against `~/.local/share/nvim`: **`just` here is a zinit wrapper with a
`#!/usr/bin/env zsh` shebang, and zsh's own startup reassigns `XDG_*` on the way
through.** `XDG_DATA_HOME=/tmp/PROBE zsh -c 'echo $XDG_DATA_HOME'` prints
`/home/aetf/.local/share`. Same family as the standing rule that `zsh -lic` lies
about `PATH`; now in `AGENTS.md` and `docs/testing.md` with the spelling that
does work.

### 8.4 Smaller notes

* **`.git-blame-ignore-revs` cannot be in the reformat commit** (§3.5 step 2
  asks for it): a commit cannot contain its own hash. Split into `22789b5` +
  `645857d`. Verified on a line the reformat actually moved — the first line
  tried was a comment it had not touched, which looks identical either way.
* **`collapse_simple_statement`**, measured because the reformat is mostly
  one-line closures being expanded and that invites second-guessing:
  `"FunctionOnly"` would keep them but touches *more* of the repo (55 files vs
  46), since it also collapses functions currently written across lines. D4's
  "leave `stylua.toml` alone" is the smaller change as well as the decided one.
* **`.luarc.json` carries no comments** — JSON, and `vim.json.decode` reads it
  in `tests/test_luarc.lua`. The reasoning for every line in it lives in that
  test file and in the `justfile`'s `lint` recipe, both of which name it.
* **`tests/` grew to 18 unformatted files** exactly as §1.4 predicted it would
  keep doing; the reformat covered 46 files in total (26 `lua/`, 2 `ftplugin/`,
  18 `tests/`), matching §1.4's r4 count.

### 8.5 Still open

* **The first real run's timings**, and therefore the caching decision (§1.3,
  §4, §7). Nothing has run on a runner yet — the branch is not pushed.
* **D1: push and PR.** The one irreversible step, held for explicit
  confirmation.
* Everything in §7 stands as written, plus the `gitsigns.toggle_deleted`
  entry §8.1 adds to it.

## 9. (r7) Acceptance review fixes

Four findings from `phase7-acceptance-review.md`, all fixed. That document is
left as the record of the audit as taken and is not rewritten.

### 9.1 R1 — the `lint` job could not have worked on a runner

`just plugins` was bare `nvim --headless '+Lazy! install' +qa`, and bare `nvim`
loads `$XDG_CONFIG_HOME/nvim`. **On this machine that directory is this repo**,
so the recipe booted this config and installed 46 plugins. On a runner the
checkout is `$GITHUB_WORKSPACE` and there is no config at all: `E492: Not an
editor command: Lazy!`, headless Neovim **exits 0** anyway, `just` sees success,
and the failure surfaced one step later in `scripts/luarc-lint-config.lua` as
advice to run the recipe that had just reported success.

**`rtp` is not the lever, which is the part worth writing down.** The first fix
tried was `--cmd 'set rtp^=<repo>' -u <repo>/init.lua`. lazy.nvim **resets** the
runtimepath to `stdpath('config')` + `$VIMRUNTIME` (`performance.rtp.reset`,
default on) before it imports specs, so the prepend is discarded and the import
reports *"No specs found for module ucw.plugins"*. Measured, not reasoned:
the attempt printed that error and `1 plugins present`.

What works is moving `stdpath()` itself, and the shape of the fix is worth more
than its content:

```just
nvim_config_env := 'XDG_CONFIG_HOME=' + parent_directory(justfile_directory())
                 + ' NVIM_APPNAME=' + file_name(justfile_directory())
```

On this machine that evaluates to `XDG_CONFIG_HOME=/home/aetf/.config
NVIM_APPNAME=nvim` — **exactly the status quo**, so it is a verified no-op here
and load-bearing everywhere else. On a runner it is `XDG_CONFIG_HOME=/home/
runner/work/ucw.nvim NVIM_APPNAME=ucw.nvim`, and the checkout becomes the config
directory by construction rather than by where it happens to be. `NVIM_APPNAME`
moves `stdpath('data')` too, so `lint` uses the same variable for the generator:
one definition, and the two recipes cannot disagree about where the plugins are.

`plugins` also checks its own postcondition now (every `require('lazy').plugins()`
entry has a directory on disk, `cquit 1` naming the missing ones), because the
generator only refuses on a *completely* empty plugin root — three failed clones
out of 46 would otherwise be a smaller library, a green check and no signal,
which is §5's failure mode with the guard one level too far downstream. The
`pcall` is not defensive style: a `-c` that errors does **not** stop the ones
after it (measured), so an unguarded verify step would itself exit 0.

**Verified the way the original could not have been.** The tree was copied to
`/tmp/…/ucw.nvim` — outside `~/.config`, named like a runner checkout — and the
recipes run from there: `just plugins` → `46 plugins present` in 8.4 s into a
fresh `~/.local/share/ucw.nvim/lazy`; `just lint` → `deps` clones mini.nvim, the
generator reports `43 library entries (41 plugins)`, `Diagnosis completed, no
problems found`. docs/testing.md's bare-runner recipe is replaced with this one;
the old `XDG_DATA_HOME`-only version is what certified the bug.

(41 rather than this machine's 42 is expected and not drift: the real data dir
carries a firenvim install from Phase 6's embedded-target boot.)

### 9.2 R2 — `:GitsignsUndoStageHunk` staged hunks

Reverted to `undo_stage_hunk()` with a `deprecated` suppression, and carried in
§7 next to `toggle_deleted`. §8.1 asked exactly the right question about
`toggle_deleted` — *are these two functions the same thing?* — and did not ask
it about the entry directly above it in the same file, calling that one
"mechanical … same surface, same intent". The surface was stable; the intent
inverted. Measured in a real TUI on a two-hunk scratch repo, `signs_staged_enable`
at its default:

| cursor | call | result |
|---|---|---|
| on an unstaged hunk, another already staged | `stage_hunk()` (r6's version) | **stages it** — the opposite of the command's name |
| between hunks | `stage_hunk()` (r6's version) | nothing; "No hunk to stage" |
| between hunks | `undo_stage_hunk()` (restored) | unstages the last-staged hunk |

The mechanism: `undo_stage_hunk` pops `bcache.staged_diffs`, a session-local
LIFO, and never consults the cursor; `stage_hunk` looks up the hunk at the
cursor and only inverts when there is no *unstaged* hunk there. Making the
command a cursor-local toggle is a behaviour decision and stays available; it is
not a lint fix. **D5's fixable list is two items, not three** — r6 already cut it
from four to three for `toggle_deleted`, by the same argument, one entry short.

### 9.3 R3 — a stale absence in `tests/test_format.lua`

The file header still argued prettier was shape-only because it *"needs `node`,
absent here"*. `mise exec -- command -v node` resolves (node 25.9.0), and
`mise exec` is the environment `just test` establishes. §1.2 (r4) had already
recorded the flip and supplied the structural replacement (`cond = is_full_ui`),
which the new markdown case at the *bottom* of the same file states correctly —
so the file carried the corrected argument and the superseded one 240 lines
apart, stale copy first. Header rewritten to the structural reason. The
parenthetical citing `lua/ucw/lsp/servers.lua` is dropped: that comment is a
conditional troubleshooting note, not a record of an absence.

### 9.4 R4 — the third library input now refuses too

`lint: deps plugins`. `.luarc.json` names three kinds of `workspace.library`
entry; `$VIMRUNTIME` and the plugin dirs each got a refusal path this phase and
`deps/mini.nvim/lua` did not, while lua_ls ignores a missing library path
without a word (§1.5a measured that and called it a feature). Measured impact
today is **zero** — stripping the entry changes no finding (0 problems at
`Warning`, the same 1 at `Information`), because `mini/test.lua` declares
`local MiniTest = {}` and only assigns `_G.MiniTest` inside `setup()`. Depended
on anyway, on this phase's own "identical today is not equivalent" standard
(§1.5b used it to add `runtime.path`).

### 9.5 Re-verified after the fixes

`just all` twice — 145/145, exit 0, no flake. `just lint` and `just fmt-check`
green. Bare-runner shape green, as above. `git status` clean, so D6's premise
still holds. §8.5's open items are unchanged: nothing has run on a real runner,
the caching decision waits on those timings, and **D1 (push + PR) is still the
one irreversible step, still held for explicit confirmation.**

### 9.6 (r8) What the first real CI run found, and it was R1 again

The first run on a real runner (PR #19) was **red**, and the acceptance review
had said the one thing that turned out to matter was safe:

> The `test` job is unaffected for exactly this reason and it is worth saying
> why: `tests/aux/driver_init.lua` and `helpers.lua` put `vim.fn.getcwd()` on
> the child's `rtp` explicitly … the harness never assumes where the config
> lives.

That was checked before §9.1 established that **lazy.nvim resets `rtp` to
`stdpath('config')`** before importing specs, and never re-checked afterwards.
The `rtp` the harness sets is real and is also discarded. So on the runner
lazy imported no specs, installed nothing, and every integration case died in
`pre_case` at `require('mini.test')` — that copy is the *runtime* mini.nvim
lazy installs (`lua/ucw/plugins/mini.lua`), not `deps/mini.nvim`. Observed:
`test_boot` and the first case of every integration file red, `test_health` all
eight red, the unit-only files (`deprecations`, `lsp_actions`, `luarc`,
`ipython_cell`) all green — exactly the plugin/no-plugin split. Then
`test_treesitter`'s `boot_with_attached_ui` waited on a second Neovim that could
never come up, and the job burned the remaining 18 minutes to
`timeout-minutes: 20`. `lint` and `format` were green, so §9.1's fix did hold.

**Fix: `test` gets the same `{{ nvim_config_env }}`.** One more caller of the
lever that already existed; no new mechanism.

**The dud that made this take three tries is the part worth keeping.** Running
the suite from a runner-shaped copy under `/tmp` reported **113/113 integration
cases green** while CI was red on the same commit — because `~/.config/nvim`
still exists on this machine, so `stdpath('config')` falls back to the real repo
and the copy is only half a simulation. The probe that discriminates needs an
empty `XDG_CONFIG_HOME` as well; with it, `test_health` reproduced CI's failure
exactly (`module 'mini.test' not found`, `helpers.lua:67`), and with the fix the
full suite is **145/145 in that same environment**. docs/testing.md now carries
both halves, because "copy the tree out of `~/.config`" was the lesson written
down after R1 and it was not sufficient.

Three instances now of one failure mode — `just plugins`, the `lint` library,
the test child — and all three are the same sentence: **this repo is a Neovim
config, so "where the config is" is a variable everywhere else and a constant
here.** That is the thing to check first in anything that runs `nvim`.

`timeout-minutes: 20` is left alone: it did its job, and the 18 minutes it
absorbed were a hang caused by the bug, not a slow suite.

### 9.7 (r9) The first green runs, and what they closed

PR [#19](https://github.com/Aetf/ucw.nvim/pull/19). Both trigger paths green at
`d7f6cc5`, run conclusion `success` on `push` and on `pull_request`.

**§8.5's two open items are closed.**

* **D1 is done** — branch pushed, PR open. The pre-push content check §5 asked
  for was done rather than asserted: no secret-shaped strings, one author and
  one committer identity across all 38 commits, the six `/home/aetf/...` hits
  all pasted error output in `docs/`, nothing added-then-deleted except Phase
  1's `lua/nvimd/`.
* **Caching is decided, and the answer is "no".** §1.3 deferred it to the first
  run's real numbers rather than guessing at runner network. The numbers:

  | job | wall clock |
  |---|---|
  | `test` (either leg) | **~2.5 min** |
  | `lint` | ~1.8 min |
  | `format` | ~11 s |

  Ten cold installs of 46 plugins, once per integration file, cost so little on
  a runner that a cache would be complexity bought against nothing. The local
  93 s figure §1.1 measured is the same order. **§7's cache entry is
  removed, not deferred again.**

**Two of §4's verifications happened by themselves rather than on purpose.**
The `nightly` leg is genuinely red — `test_fold`'s fold-text case and
`test_lsp`'s inlay-hint detach/reattach case fail on `NVIM v0.13.0-dev-1307`,
which is the leg doing exactly its job — and both workflow runs still report
`success`, so `continue-on-error` is confirmed against a real failure instead of
a manufactured one. Per §5 that leg stays: two named, reproducible, actionable
failures are the opposite of the "red for three months for no actionable reason"
case that says to delete it. Fixing them is not this phase's.

**One flake is outstanding and deliberately not chased with a retry.**
`test_tui_screenshot.lua | sees buffer text on screen` went red once, at
`3afd9fe`, on the `push` run while the `pull_request` run of the same commit was
green; 144/145 otherwise. Six local repeats do not reproduce it. Both cases in
that file asserted `screen:find(...) ~= nil` against `true`, which reports
`false ~= true` and discards the only fact that could explain it — what was
drawn instead. `expect_on_screen` now errors with the whole rendered grid
(reverse-verified per F5). The next red run is the one that explains it. Per §5
and the standing rule: no retry, no sleep, root-cause when there is evidence.

### 9.8 (r10) The three loose ends, and the one thing they were

§9.7 left three: an unexplained screenshot flake on `stable`, two red cases on
`nightly`, and the standing blink.cmp popup bug (§6). The first two turned out
to share a mechanism, and finding it cost nothing because §9.7's instrumentation
was already in place - the *nightly* leg hit the flake on its next run and
printed the screen:

```
01|▎   󰈔 [No Name]    ●
02|   1   hello from ucw.╭──────────────────────  ──────────────────────╮
03|     1 second line    │ Neo-tree ERROR Error in setup for vim_buffer_…│
04|~                     ╰───────────────────────────────────────────────╯
05|~                          ╭──────────────  Messages ─────────────────╮
```

**A notification is a float, and a float lands on whatever is on screen.** Two
of this suite's cases read the rendered screen, and both were at the mercy of
any notification that happened to arrive first. On `nightly` the notification is
neo-tree's startup error; on `stable` there is no error and the only candidate
is the `blink.cmp  Downloading pre-built binary` notice that a cold install
emits - which is why it was rare, and why it never reproduced locally, where the
timing differs.

**The findings, separated because they are separate:**

* **A real 0.13 incompatibility, not ours and not hidden.** `BufModifiedSet`
  was **removed** in 0.13 (`news.txt`: use `OptionSet` with pattern `modified`);
  neo-tree's `define_autocmd_event` still registers it, so its event setup dies
  with `E216: No such group or event`. Upstream fixed this on `main`
  (nvim-neo-tree/neo-tree.nvim#2023, merged 2026-04-27) and **not** on the
  `v2.x` branch this config pins - and we are already at that branch's tip
  (`80dc74d`), so there is no bump that fixes it. Moving off `v2.x` is a
  plugin decision, not a CI fix. **Carried to §7.**
* **`test_lsp`'s detach case was pinning an upstream decision it does not own.**
  On 0.12.4 the `LspDetach` handler `_disable()`s the buffer; on 0.13-dev it no
  longer does. The case asserted the intermediate `false`. Now it *observes*
  that value and asserts only the behaviour that is ours - hints are on after a
  reattach - while recording that what the pass is worth depends on which side
  upstream is on.
* **`test_fold` was never about folding here.** Its screen scan read the float
  instead of the fold line (`function! Foo()╭─── Error ───╮`). It dismisses
  notifications first now, like `test_tui_screenshot`.

**The new case, and the two dud versions of it that came first.** Dismissing
notifications in the screen tests removes the symptom, so something had to own
the question "does this config raise an error notification". Two attempts were
green when they had to be red:

1. *Read `Snacks.notifier.get_history()` after boot* - red, green, red across
   three identical nightly runs.
2. *Wrap `vim.notify` before `ucw.boot()`* - green 3/3. Booting **replaces**
   `vim.notify` (noice, snacks behind it), so the wrapper was thrown away;
   plugins resolve `vim.notify` at call time and land on whichever side of the
   swap they run on. Unioning both sources still measured red, green, red.

The remaining nondeterminism was not in the recording but in the event:
neo-tree's sources subscribe when the tree is **first opened**, so whether it
happens during boot at all is a race. `tests/test_neotree.lua` opens the tree
and asserts no error-level notification: **3/3 red on 0.13-dev, 3/3 green on
0.12.4.** It is a file of its own rather than a case in `test_boot.lua`,
because "booting works" and "neo-tree works" are two owners.

**Result.** `stable` 146/146 green twice; `nightly` 145/146, the single failure
being a named, deterministic, actionable incompatibility instead of two mystery
cases. That is what the advisory leg is for, and §5's "delete it if it is red
for something unactionable" does not apply.

### 9.9 (r11) The blink.cmp popup, root-caused

§6 has carried this since Phase 6: *"a completion popup appears in a freshly
opened `.lua` buffer with no keypress"*, confirmed a real bug by the user
2026-08-06 and never diagnosed. It is diagnosed now, and it was never about
`.lua` files.

**It depends on how the file is opened**, which is why it looked arbitrary:

| how | menu in normal mode |
|---|---|
| `nvim foo.lua` (file as argument) | no |
| typing `:edit foo.lua<CR>` | **yes** |
| `tui-drive`'s programmatic `cmd 'edit …'` | **yes** |

So the common factor is *the cmdline was used*, not the filetype - and it
reproduces with real typed keys, so it was never an artefact of driving Neovim
over a socket.

**Mechanism, read off a live traceback** rather than guessed: `blink.cmp`'s
`lib/cmdline_events.lua` hooks `vim.on_key`, checks `mode == 'c'` **at key
time**, and then defers the reaction through `vim.schedule`. Submitting the
cmdline runs the command before that callback gets its turn, so
`on_changed` → `on_char_added` → `trigger.show()` executes in **normal mode**,
completing against the buffer that was just opened. Captured by wrapping
`trigger.show` in a real TUI:

```
MODE=n
  .../completion/trigger/init.lua:63: in function 'on_char_added'
  .../lib/cmdline_events.lua:28: in function 'on_changed'
  .../lib/cmdline_events.lua:47: in function <.../cmdline_events.lua:46>
```

The 33 items are the `snippets` source (`dateMDY`, `copyright`, `uuid`, …),
which is why the menu always looked unrelated to anything typed. It also eats
the next keystrokes, which is how it corrupted a scratch file during Phase 6's
TUI work.

**Upstream, and not fixable by moving.** `v1.10.2` (2026-04-04) is the latest
release and is what this config pins. So this is a workaround, taken knowingly
and with the race understood - the standing rule is against workarounds for
*unknown* causes.

**Written as the invariant, not as an undo of that path.** The menu is an
insert/cmdline-mode object; anything that opens it elsewhere is wrong however it
got there. `blink-cmp.lua` hangs one autocmd on blink's own `BlinkCmpMenuOpen`
and hides the menu when the mode is not one of `i`/`c`/`R`/`s`/`S`.

**The regression test asserts both halves in one case**, because "the menu is
not visible" passes just as well when the menu never opened - and in a headless
child, where this file's own header says keyword-triggered completion is
unreliable, that is exactly what would otherwise happen. So it shows the menu
through the entry point the bug uses, asserts the guard closed it, *then* clears
the guard and asserts the same call does leave it open. Reverse-verified per F5
by deleting the guard: `Left: { true, "n" }` against `Right: { false, "n" }`.

**§6 is closed.** 147/147 on 0.12.4 twice; 146/147 on 0.13-dev, the one failure
still being §9.8's named neo-tree incompatibility.
