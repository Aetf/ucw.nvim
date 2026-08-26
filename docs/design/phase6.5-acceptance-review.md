# Phase 6.5 acceptance review

Reviewed: commits `23dd552` ("Phase 6.5: declared here, resolved by the
project") and `bc044dc` ("Phase 6.5 r5: what the real TUI said, which was not
what the doc said") against `docs/design/phase6.5-binary-deps.md` (r5) and the
`phase7-ci.md` delta list the phase owes it (§8).

**Verdict: accept, with five fixes applied.** One is a live regression this
phase introduced (R1), reproduced end-to-end before being fixed; the other four
are statements — in code comments and in the two docs a contributor actually
reads — that this phase's own measurements falsified and did not go back to
correct. R3 is the one worth reading even if nothing else is: `docs/testing.md`
asserts the exact opposite of the fact R1 turned on, which is the likeliest
single reason R1 was written the way it was.

Same rule as previous reviews: everything marked **measured** was produced on
this machine (Neovim 0.12.3, mise 2026.7.11) against the real config. Nothing
here is inferred from reading the diff.

---

## 1. Findings

| # | Finding | Kind | Severity |
|---|---|---|---|
| R1 | The boot-time treesitter parser install fires under **firenvim and vscode-neovim**: they attach a UI of their own, so `#nvim_list_uis() > 0` is true in exactly the two contexts this config keeps automatic installs out of | regression, live | medium |
| R2 | `docs/testing.md` documents the test invocation **without** the `mise exec --` this phase made load-bearing — following the doc gives 7 red cases out of 15 in `test_format.lua` alone | doc, self-inflicted | medium |
| R3 | `docs/testing.md`: "the child has a real UI attached, which is what makes screenshots possible" — false on both halves, and it is precisely the fact R1 got wrong | doc, actively misleading | medium |
| R4 | `lua/ucw/plugins/ufo.lua` still explains a design decision with "this machine has no `tree-sitter` CLI", which §3.3 of this phase disproved | stale comment | low |
| R5 | `docs/tui-observation.md`'s worked example cites a Phase-1-deleted file, a Phase-1-deleted log, a parser no longer in `ensure_installed`, and a "not via mise" claim §3.3 disproved | stale doc | low |

The pattern the previous four reviews established held again, in a new
variation. Phase 3: the seams between two owners. Phase 4: scope quietly
changed while moving. Phase 5: the risk the doc itself named loudest went
untested. Phase 6: the one seam the design doc never crossed. **Phase 6.5:
every finding is downstream of the same sentence — "nothing installs itself in
a session with no UI attached" (§2.3b) — which was borrowed from Mason without
checking that Mason's version of the rule has a second layer this one does
not.** R1 is that gap in code; R3 is the document that would have revealed it
and instead asserts the opposite.

---

### R1 — the parser install fires under firenvim and vscode-neovim (medium)

§2.3b introduced the gate, on a user decision made the same day, in these
terms: *"nothing installs itself in a session with no UI attached"*, described
as *"the rule Mason already applies to its own automatic installs, and which
`tests/test_lsp.lua` already asserts as a precondition"*.

**Mason's rule has two layers here, and the gate copied only the inner one.**

* `lua/ucw/plugins/mason-tool-installer.lua` and
  `lua/ucw/plugins/mason-lspconfig.lua` both carry `cond = is_full_ui`, so
  under an embedded target lazy.nvim never loads them at all. That is the outer
  layer, and it is the one that keeps Mason out of firenvim/vscode-neovim.
  Phase 6's own second-round fix (`df33355`) turns on this exact fact: *"mason
  is never loaded under firenvim"*.
* Mason's own "skip when no UI is attached" is the inner layer, and it is what
  `tests/test_lsp.lua`'s `ensure_installed cannot fire inside the test child`
  asserts. It only ever applies *underneath* the outer one.

`nvim-treesitter` has no `cond` — it is `lazy = false, priority = 1000`,
deliberately, because the embedded targets do want its highlighting. So it had
no outer layer, and the inner one alone does not do the job, because **firenvim
and vscode-neovim each attach a UI**: both call `nvim_ui_attach` to receive the
redraw events they paint into the browser textarea / the VS Code editor.
(Confirmed against both projects' source, not assumed — firenvim's
`nvim.ui_attach(cols, rows, {ext_linegrid: true, …})` and vscode-neovim's
`uiAttach(width, height, {ext_linegrid: true, …})` in its controller.)

**Measured, before the fix.** An `--embed` Neovim with the marker set via
`--cmd` (before the config is sourced, the only moment lazy's `cond` reads it),
a `tree-sitter` CLI on `PATH`, and a UI attached in the order both hosts use —
attach first, then boot:

```
marker=nil                      boot_ms=47    n_uis=1  is_full_ui=true   CLI invoked after 3207 ms
marker=started_by_firenvim      boot_ms=1600  n_uis=1  is_full_ui=false  CLI invoked after 1855 ms
```

The second line is the bug: a firenvim session — a browser textarea, often
alive for seconds — starting a download-and-compile of the whole 46-entry
`ensure_installed` list, with no desktop UI to show progress in. After the fix
the same probe leaves the CLI uninvoked through a 30-second condition wait,
while the full-UI control still fires in 324 ms.

**Not currently reachable on this machine, and that is not a mitigation.** A
desktop-launched process here gets `PATH=/usr/local/bin:/usr/bin` from the
systemd user environment (measured, `systemctl --user show-environment`), so no
`tree-sitter` is resolvable to a browser- or VS-Code-launched Neovim either —
the same shell/environment bug §3.3's r5 note already owns. The finding is that
the mechanism is wrong, on the same terms the rest of this phase is judged by:
§1 rule 1 is *"declaration is machine-independent"*, and this phase's whole
point was to stop the config depending on accidents of what happens to be on
`PATH`. §2.3b even says so about its own gate — *"this is not new fragility, it
is old fragility becoming reachable"*. This is the other half of the same
sentence.

**Fix.** `lua/ucw/plugins/treesitter.lua`, one condition:

```lua
if #vim.api.nvim_list_uis() > 0 and require('ucw.targets').is_full_ui() then
```

Both halves are needed and neither is redundant: `is_full_ui()` alone would let
every headless run and every mini.test child install parsers (which is what
§2.3b was fixing), and `nvim_list_uis()` alone is what shipped. `:TSUpdate` and
`:TSInstall` remain untouched, so an embedded session can still install
deliberately — the line this phase's D-decisions keep drawing is *explicit
versus automatic*, and it is drawn here the same way Phase 6's r6 drew it for
`format_on_save`.

**Tests** (`tests/test_treesitter.lua`, `embedded contexts` group, 3 cases).
The technique is the finding's own reproduction: a second Neovim over RPC with
a UI genuinely attached, since mini.test's child has none and cannot be made to
have one. What is observed is whether `require('nvim-treesitter').install` is
**called**, recorded by wrapping the global `require` before `ucw.boot()` — the
`nvim_exec_lua` that boots is a blocking request and treesitter's `config()`
runs inside it, so the counter is final the moment it returns. Synchronous,
hermetic, no network, no compilation.

> **The first version of this test was a dud, in the direction that matters.**
> It watched for the `tree-sitter` binary being executed and asserted
> immediately — but the install is asynchronous, so it asserted "nothing
> happened" a second or two before anything would have. It passed with the fix
> **and** with the fix reverted. This is Phase 4's F5 rule paying for itself for
> the fifth review running: the reverse verification is what caught it, and
> what forced the switch to a synchronous observable.

Reverse-verified after the rewrite: with the `is_full_ui()` conjunct removed,
the two embedded cases fail `1` vs `0` and the full-UI positive control stays
green. The positive control exists so that a `boot_with_attached_ui` which
silently failed to boot at all could not pass every embedded case by reporting
zero.

---

### R2 — the documented way to run the tests is now the broken way (medium)

§2.3a is one of this phase's two unplanned-but-forced changes, and it is
correct: every `justfile` recipe that runs a binary now runs it through
`mise exec --`, because *"a shell only has the project's tools if `mise
activate` ran in it, and one measurably had not"*. It even reverse-verified
itself — *"with the `mise exec` removed from the `test` recipe, six cases in
`tests/test_format.lua` go red"*.

`docs/testing.md` was not updated, and it prints the invocation twice:

```sh
nvim --headless --clean \
  --cmd 'let g:TestTags = "<tags>"' \
  ... -u ./tests/aux/driver_init.lua -S ./tests/aux/driver_run.lua
```

```sh
nvim --headless --clean -u tests/aux/driver_init.lua \
  -c "lua MiniTest.run_file('tests/test_tui_screenshot.lua')" -c "qa!"
```

**Measured**: the first, run verbatim from this repo against
`tests/test_format.lua`, gives **7 failures out of 15** — the six §2.3a
predicted plus the `PATH order` case the phase added afterwards. The shell it
was run from has no `stylua`, `ruff` or `taplo` (`which` reports all three
missing), which is exactly the §3.3 situation the whole phase is about.

The second snippet matters more than the first, because it is the one used
while iterating on a single file — including for the reverse verifications
these reviews depend on — and `docs/testing.md` line 9 still describes
`just deps` as *"clone/update mini.nvim into deps/mini.nvim"*, with no mention
that it is now also what provisions the pinned binaries, or that `mise` is a
new hard prerequisite (§6 names that risk: *"a second tool the contributor
instructions have to name"* — this is where it would have been named).

**Fix**: both snippets gain the `mise exec --` prefix with the one-line reason,
`just deps`'s description covers both halves, and the prerequisites are stated
where §6 said they would have to be.

---

### R3 — `docs/testing.md` asserts the opposite of the fact R1 turned on (medium)

> 2. **Child** — each test spawns a fresh child nvim per case
>    (`MiniTest.new_child_neovim()`), driven over RPC. **The child has a real UI
>    attached, which is what makes screenshots possible** (see
>    `tui-observation.md`).

Both halves are false, **measured against `deps/mini.nvim` directly**:

* mini.test starts the child with `--headless` and `--cmd 'set lines=24
  columns=80'` (`mini/test.lua:1176-1180`) and calls `nvim_ui_attach`
  **nowhere** in the file. `#vim.api.nvim_list_uis()` in the child is `0` — two
  test files already assert exactly that as a precondition
  (`tests/test_lsp.lua`, `tests/test_treesitter.lua`).
* Screenshots do not come from a UI. `child.get_screenshot`
  (`mini/test.lua:1408`) reads `vim.fn.screenstring()`/`screenattr()` over
  `vim.o.lines × vim.o.columns` — the internal screen buffer the `set lines/
  columns` above sizes, which is why the `--headless` child can produce one at
  all.

This is not pedantry about a doc, it is **the fact R1 is made of**, stated
backwards in the place someone would check it. Read as written, it says a UI is
attached in tests — from which `#nvim_list_uis() > 0` reads as a gate that is
*false where it should be true* (uselessly blocking nothing in tests), and the
question "so which real sessions have a UI?" never gets asked. The truth is the
mirror image: the child has no UI (so the gate works there, which is what
§2.3b wanted) and the embedded hosts do (so it fails where it mattered).

**Fix**: correct both halves, and name the two test files that assert the
precondition so the next person finds the assertion rather than the prose.

---

### R4 — `ufo.lua` still argues from "this machine has no `tree-sitter` CLI" (low)

`lua/ucw/plugins/ufo.lua:42-43`, justifying why `has_parser` probes the running
Neovim instead of reading `ensure_installed`:

> a parser listed there is not necessarily compiled (this machine has no
> `tree-sitter` CLI, so only Neovim's bundled parsers exist)

§3.3 of this phase is a table whose entire point is that this machine **does**
have `tree-sitter` 0.26.11, installed via mise, deliberately, for this editor —
and that the config could not see it. The *decision* the comment defends is
still right (and Phase 4's F1/G1 are why), but its stated reason is now a
machine-specific claim this phase disproved, of exactly the kind Phase 5's R5
was about: a file-header comment left contradicting what the phase established
30 lines away.

**Fix**: re-argue it from the durable reason — a listed parser is not a
compiled parser regardless of what any given machine has — and drop the
machine-specific parenthetical, with a pointer to §3.3 for the history.

---

### R5 — `tui-observation.md`'s worked example is stale four ways (low)

The "Worked example: a real startup bug found with these tools" section
(lines 125-152) contains, in six lines:

* `lua/ucw/units/thirdparty/treesitter.lua` — `lua/ucw/units/` was deleted in
  Phase 1 (verified: no such directory).
* `nvimd.log` — the nvimd engine was deleted in Phase 1.
* `latex` is in `ensure_installed` — it is not (verified: no `latex` anywhere
  in `lua/ucw/plugins/treesitter.lua`).
* the CLI is *"not installed (not on `PATH`, not via mise/npm/mason)"* —
  §3.3 disproves the mise clause specifically.

Phase 5's R7 already found this file pointing at Phase-1-deleted machinery
(`nvimctl:start`) and fixed that instance; this section was not swept at the
same time. `docs/testing.md`'s "Gaps" section points a reader straight at it.

**Fix**: rewrite the example to say what it is — a bug found in the pre-Phase-1
config, kept because the *method* is what the section teaches — with the
present-day facts corrected and the dead paths marked as historical.

**Deliberately not fixed here**: `docs/architecture.md` is still a full document
describing the deleted `nvimd` engine as the current architecture. That is
Phase 1 debt and it is *scheduled* — Phase 10 is "Docs, extension-point notes,
final pass" — so rewriting it inside a Phase 6.5 review would be the scope
creep these reviews keep declining. Recorded here so it is not rediscovered a
sixth time.

---

## 2. Re-measured and confirmed true

Recorded so a later pass does not redo it:

* **`PATH = 'append'` holds, structurally and behaviourally.** Mason's bin
  directory is last on `PATH` after it loads, and a `stylua` placed ahead of it
  is the one conform runs (`tests/test_format.lua`'s `PATH order` group, green;
  §10's account of both directions re-confirmed).
* **The rustup switchover is real where rustup is reachable.**
  `rustup component list --installed` shows
  `rust-analyzer-x86_64-unknown-linux-gnu`; the shim answers `rust-analyzer
  1.89.0 (2948388 2025-08-04)` with exit 0; the binary is dated
  **2026-08-09 21:55**. §2.2's r5 correction is accurate — D5 needed no action
  at landing.
* **`just deps` needs no `mise trust`.** Run from a shell with `mise` on
  `PATH`: `mise all tools are installed`, exit 0, nothing authorized. The r5
  correction to §2.3 stands.
* **§5's "remove `mise` from `PATH` and confirm `just deps` fails loudly" leg
  still cannot be run here — but now for a *known* reason, which is worth more
  than the leg was.**

  > **This bullet was wrong when first written**, and is corrected in place
  > rather than quietly dropped, because getting it wrong is the same mistake
  > this review's R1-R5 are about. It originally claimed the leg was closed.
  > It is not.

  Stripping both mise directories from `PATH` and invoking `just` by absolute
  path still gives `mise all tools are installed`, exit 0 — mise is found
  anyway. The mechanism: `just` on this machine is
  `~/.local/share/zsh/zinit/polaris/bin/just`, a **`#!/usr/bin/env zsh`
  wrapper**, so every `just` invocation launders the environment through a
  fresh zsh, and every zsh start puts `zinit/polaris/bin` back on `PATH` —
  which contains a `mise` wrapper of the same kind. Measured: `env PATH=<no
  mise> bash -c 'command -v mise'` reports nothing, while the same `PATH` into
  `zsh -c 'command -v mise'` resolves
  `~/.local/share/zsh/zinit/polaris/bin/mise`. r5's stated reason ("`mise` is
  on `PATH` by construction here") was right in substance and understated the
  mechanism; the leg is un-runnable on this machine short of a container.

  **This also sharpens §3.3's diagnosis, and whoever fixes the dotfiles should
  read it there.** The five-entry `PATH` r5 measured is not missing `mise` —
  `zinit/polaris/bin` is its first entry and a working `mise` lives in it.
  What is missing is **`mise activate`'s injection of the tool paths**. So the
  bug is not "mise never loads", it is "something after it assigns `path`
  and discards what activate added" — which is consistent with r5's other
  observation that `/usr/local/sbin`, the perl dirs, `/usr/lib/rustup/bin` and
  krew all vanish too, and it narrows the search to whatever runs *after*
  activate rather than to activate itself.
* **`:checkhealth ucw` reports all three declared/installed states plus OK,
  discriminatingly** (`tests/test_health.lua`, 8 cases green), and the two
  self-inflicted bugs §10 confesses (registry refresh ordering, the bare
  `require` of `mason-lspconfig.mappings`) are both genuinely fixed in
  `lua/ucw/health.lua` — the refresh is hoisted into `M.check()` above every
  reader, and module availability is reported rather than re-derived from
  `ucw.targets`.
* **`just fmt-check` and `just lint` are red for the documented reasons only**
  (Phase 7's D3 reformat commit and `.luarc.json` respectively), not for new
  ones. Both are recipes this phase owed Phase 7, not gates it claimed to pass.
* **`just all`: 138/138 green ×2** before this review touched anything, and
  `lazy-lock.json` unchanged after.

---

## 3. Fixes applied

Commit: see `git log` following this document.

| # | Fix |
|---|---|
| R1 | `lua/ucw/plugins/treesitter.lua`: the boot-time install is gated on `#nvim_list_uis() > 0 **and** is_full_ui()`, with the two-layer Mason precedent written out. `tests/test_treesitter.lua` grows an `embedded contexts` group of 3 cases (full-UI positive control + firenvim + vscode-neovim) driving a real second Neovim with a genuinely attached UI |
| R2 | `docs/testing.md`: both invocation snippets carry `mise exec --`; `just deps` is described as provisioning the pinned binaries *and* mini.nvim; `mise` named as a prerequisite |
| R3 | `docs/testing.md`: the child is `--headless` with **no** UI attached, screenshots come from `screenstring()`/`screenattr()` over the internal screen buffer, with the two asserting test files named |
| R4 | `lua/ucw/plugins/ufo.lua`: the `has_parser` rationale re-argued from the durable reason, machine-specific claim dropped |
| R5 | `docs/tui-observation.md`: the worked example marked as pre-Phase-1 history, dead paths and the mise claim corrected |

## 4. Verification of the fixes

**Suite: 141 cases, green ×2** (138 + 3).

**Reverse verification (R1)**, per Phase 4's F5 rule: with the `is_full_ui()`
conjunct removed, `a UI-attached firenvim session installs nothing` and `a
UI-attached vscode-neovim session installs nothing` both fail `1` vs `0`, and
`a UI-attached full-UI session does install` stays green. Restored, 5/5.

**Reverse verification (R2)**: the pre-fix snippet, run verbatim, gives 7
failures out of 15 in `tests/test_format.lua`; the same command with
`mise exec --` gives 15/15.

**Not independently re-verified in a live firenvim or VS Code host**: neither a
browser nor VS Code is available in this environment. The probe reproduces the
mechanism rather than the host — `nvim_ui_attach` on an `--embed` process with
the target marker set via `--cmd`, which is what both hosts do — and this is
the same limitation every `cond`-dependent test in this suite already carries
(`tests/test_fold.lua`, `tests/test_format.lua` and `tests/test_health.lua` are
all headless-only for the same reason).

**Deliberately not changed:**

* **`docs/architecture.md`** — see R5. Phase 10 owns it.
* **The `blink.cmp` popup on a freshly opened `.lua` buffer** (Phase 6 r4,
  user-confirmed) is still out of scope and still unfixed.
* **The shell `PATH` bug** (§3.3's r5 note) stays a dotfiles problem and this
  phase's stated non-goal. It remains the single highest-value thing to fix
  next, and R1 adds a small wrinkle worth knowing when it is: the fix makes
  `tree-sitter` reachable to terminal sessions, and possibly to
  desktop-launched ones, which is the moment §9's carried-forward item about
  what an *interactive* session does on first parser compile stops being
  hypothetical.
