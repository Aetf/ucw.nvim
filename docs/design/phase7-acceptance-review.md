# Phase 7 acceptance review (2026-08-13)

Independent audit of `2529804..22fc53d` (eight commits: §3.5's seven plus the
r6 design-doc update), against `docs/design/phase7-ci.md` r6. Written after
re-measuring on this machine rather than from the design document's own
numbers.

## Verdict

The gates themselves are sound and the arithmetic in the document holds up.
**Four findings**, one of them a blocker for the thing this phase exists to
produce, one a behaviour regression shipped as a lint fix.

The shape this round: **§8.2 asked the right question one level too shallow.**
It noticed the `lint` job had no plugins and answered "make `lint` depend on
`just plugins`". It did not ask whether `just plugins` itself works on a
runner. It does not — for a reason that is invisible on the one machine where
this config lives at `~/.config/nvim` (R1). The second finding is the
neighbouring half of a triage §8.1 got right: it re-examined
`toggle_deleted → preview_hunk_inline` and correctly refused to swap them,
while leaving `undo_stage_hunk → stage_hunk` classified as "mechanical" (R2).
Both are the same question — *are these two functions the same thing?* — asked
once and not twice.

## What was re-verified and holds

Everything below was measured here, not read off the document.

* **Suite**: `just all` twice on the tree as committed — **145/145, exit 0**,
  2:11 and 2:10 wall clock. No flake, including the known `test_boot`
  hit-enter intermittent.
* **`just fmt-check`**: green, exit 0. `stylua .` does not descend into
  gitignored `deps/` (checked: `--output-format=summary` reports all files
  correctly formatted with `deps/mini.nvim` on disk).
* **`just lint`**: green, exit 0, "Diagnosis completed, no problems found".
  The generator reports **44 library entries (42 plugins)**, exactly §1.5's
  configuration B.
* **The reformat commit is pure.** `22789b5^` checked out into a scratch
  worktree, `mise exec -- stylua .` applied, then diffed against `22789b5`:
  **empty**. 46 files, byte-for-byte what stylua produces, nothing smuggled in
  — which is the property `.git-blame-ignore-revs` is claiming on its behalf.
  The SHA in that file matches.
* **All four action versions exist and are current** (`gh api
  repos/*/releases/latest`): `actions/checkout` v7.0.1, `rhysd/action-setup-vim`
  v1.6.1, `extractions/setup-just` v4, `jdx/mise-action` v4.2.5. `mise-action`
  does have a `version:` input (its `action.yml` documents it as defaulting to
  the latest release), and `jdx/mise` **does** have a `v2026.7.11` tag, so D13's
  pin resolves.
* **The `t` fix is real.** `M.t` is `lua/ucw/utils.lua:227`; the `s`/`S`
  handlers call it. Before this commit nothing bound `t` in that file.
* **Docs**: AGENTS.md's 4-space `tests/` convention is gone, "No CI" is gone
  from both AGENTS.md and docs/testing.md, README carries the badge and an
  out-of-date banner. `.luarc.json`'s globals (`vim`, `MiniIcons`, `MiniTest`)
  are a strict superset of `after/lsp/lua_ls.lua`'s (`vim`, `MiniIcons`), which
  is what `tests/test_luarc.lua` asserts.
* **The tree is clean** after two full suite runs plus `just lint` — no
  lockfile churn, which is D6's premise.

## R1 (blocker) — the `lint` job cannot work on a GitHub runner

`just plugins` is `nvim --headless '+Lazy! install' +qa`. Bare `nvim` loads
`$XDG_CONFIG_HOME/nvim`. **On this machine that directory *is* this repo**, so
the recipe boots this config, lazy.nvim bootstraps, and 46 plugins land in
`stdpath('data')/lazy`. On a runner the checkout is at `$GITHUB_WORKSPACE` and
`~/.config/nvim` does not exist, so `nvim` starts with no config at all.

Measured, with the config side varied for the first time (empty scratch
`XDG_CONFIG_HOME`, scratch `XDG_DATA_HOME`, `MISE_DATA_DIR` left alone per
docs/testing.md):

```
$ XDG_CONFIG_HOME=$c XDG_DATA_HOME=$d mise exec -- nvim --headless '+Lazy! install' +qa
Error in command line:
E492: Not an editor command: Lazy! install
$ echo $?
0
$ ls $d/nvim/lazy
ls: cannot access '.../nvim/lazy': No such file or directory
$ XDG_CONFIG_HOME=$c XDG_DATA_HOME=$d mise exec -- nvim --clean -l scripts/luarc-lint-config.lua .luarc.json /tmp/out.json
luarc-lint-config: no plugin root at .../nvim/lazy - run `just plugins` ...
$ echo $?
1
```

So the `lint` job is **red on every run**, and its message tells the reader to
run `just plugins` — the recipe that reported success one step earlier.

Two things make this worth more than "add `-u init.lua`":

* **§8.3's bare-runner verification could not have caught it.** It varied
  `XDG_DATA_HOME` and nothing else; docs/testing.md now ships that exact
  command as *the* way to simulate a runner. The variable that matters for
  this repo is the other one, precisely because this repo is a Neovim config
  and its own identity as `~/.config/nvim` is the thing a runner does not
  reproduce. The `test` job is unaffected for exactly this reason and it is
  worth saying why: `tests/aux/driver_init.lua` and `helpers.lua` put
  `vim.fn.getcwd()` on the child's `rtp` explicitly and call
  `require('ucw').boot()` — the harness never assumes where the config lives.
  `just plugins` is the first recipe in this repo that does.
* **`just plugins` has no failure of its own.** Headless `nvim` exits 0 after
  `E492`, so `just` sees a successful recipe. The only guard is downstream in
  the generator, and it fires only on a *completely* empty plugin root — a
  runner where three of 46 plugins fail to clone produces a smaller library
  list, a green check, and no signal, which is §5's failure mode with the
  refusal path built one level too far away from the thing that can fail.

Fix shape (not applied): make the recipe name the config it means to load
(`nvim --headless -u init.lua …`, or `--cmd 'set rtp^=…'`), and have it verify
its own postcondition rather than delegating that to the generator. Whatever
the spelling, the bare-runner probe in docs/testing.md needs
`XDG_CONFIG_HOME` set to something empty, or it will keep certifying this.

## R2 (regression) — `:GitsignsUndoStageHunk` now stages hunks

`undo_stage_hunk() → stage_hunk()` is listed in D5 and §8.1 as one of the three
"local, mechanical" fixes: *"upstream unified the two operations; same surface,
same intent."* The surface is stable. The intent is not.

Read from the installed gitsigns (`lua/gitsigns/actions.lua`):

* `undo_stage_hunk()` pops `bcache.staged_diffs` — a **session-local LIFO** —
  and unstages whatever comes off it. The cursor is not consulted.
* `stage_hunk()` looks up the hunk **at the cursor**, and only inverts
  (unstages) when there is *no unstaged hunk* there.

Measured in a real TUI (`tui-drive`) against a scratch repo with two separated
hunks, `signs_staged_enable` at its default `true`:

| cursor | call | result |
|---|---|---|
| on unstaged hunk B, A already staged | `:GitsignsUndoStageHunk` (as built) | **B gets staged** — index goes from `{A}` to `{A, B}` |
| on no hunk at all | `stage_hunk()` (as built) | nothing; "No hunk to stage" |
| on no hunk at all | `undo_stage_hunk()` (as before) | unstages the last-staged hunk |

So a command named `UndoStageHunk` now **stages** when the cursor happens to sit
on an unstaged hunk, and does **nothing** when the cursor is between hunks,
where it used to work. This is the same question §8.1 asked about
`toggle_deleted` — *are these two functions the same thing?* — answered
correctly there and not asked here, in the same commit, about the entry
directly above it in the same file.

Fix shape (not applied): the honest options are (a) treat it like
`toggle_deleted` — keep `undo_stage_hunk()` with a `---@diagnostic
disable-next-line: deprecated` and a §7 entry saying upstream's replacement is
not equivalent, or (b) decide deliberately that the command becomes a
cursor-local toggle and rename it. (a) is the smaller change and matches the
reasoning already written 30 lines below it.

## R3 (stale statement) — `tests/test_format.lua` argues from an absence that is gone

The file header still says prettier is covered "by shape only" because it
*"needs `node`, absent here (the same gap `lua/ucw/lsp/servers.lua` already
documents for `jsonls`)"*. Measured: `mise exec -- command -v node` and `npm`
both resolve (mise-managed node 25.9.0) — and `mise exec` is exactly the
environment `just test` establishes, so it is the environment the child
inherits.

The design document already caught this: §1.2 (r4) records the sentence
flipping and supplies the better reason — `mason-tool-installer`'s
`cond = is_full_ui`, which holds *by construction* on any machine. The new
markdown case at the bottom of this same file states that reason correctly and
at length. So one file now carries the corrected argument and the superseded
one 240 lines apart, with the stale copy at the top where a reader starts.

The parenthetical is also not quite right in its own terms:
`lua/ucw/lsp/servers.lua:47-50` is a *conditional troubleshooting note* ("if it
silently fails to attach, check the log for `env: 'node'`"), not a record of an
absence — so it does not document the gap being cited.

## R4 (minor) — one library input refuses loudly, one accepts silently

`.luarc.json`'s `workspace.library` has three kinds of entry, and `just lint`
treats them inconsistently:

| entry | missing → |
|---|---|
| `$VIMRUNTIME/lua` | recipe refuses, exit 1 (built this phase) |
| plugin `lua/` dirs | generator refuses, exit 1 (built this phase, §8.2) |
| `deps/mini.nvim/lua` | **silently ignored** |

`lint` depends on `plugins`, not on `deps`, and the CI `lint` job runs no
`just deps` — so on a runner that third entry resolves to nothing, and lua_ls
ignores a non-existent library path without a word (§1.5a measured exactly that
and called it a feature).

Measured impact today is **zero**: the same check with the entry stripped
produces the identical result (0 problems at `--checklevel=Warning`; 1 at
`Information`, `ftplugin/tex.lua:234`, in both). `mini/test.lua` declares
`local MiniTest = {}` and only assigns `_G.MiniTest` inside `setup()`, so the
library contributes no global annotations for `tests/` to resolve against.

Reported anyway because the phase's own standard is that "identical today is
not equivalent" (§1.5b used that argument to add `runtime.path`), and because
the asymmetry is the interesting part: two of three inputs got a refusal path
this phase and the third did not. `lint: plugins deps` is one word.

## Not findings, checked and dismissed

* **`format` job has no Neovim** — correct; `just fmt-check` is stylua only.
* **`test` job runs `just deps` and then `just ci`, which depends on `deps`
  again** — redundant, not wrong; `mise install` is idempotent and the
  `deps/mini.nvim` block is a no-op once converged.
* **`push` + `pull_request` both firing on a PR branch** — two runs per push,
  and D1 asks for exactly that ("both trigger paths exercised from the first
  run"). The `concurrency` groups differ by `github.ref`, so they do not cancel
  each other.
* **`lint` job never runs `mise install`** — `mise exec` installs on demand,
  and `mise-action`'s own `install` input defaults to `true`.
* **`servers.lua`'s jsonls comment** — see R3; the comment itself is fine, only
  the citation of it is wrong.
* **§8's own numbers** — "seven commits", "145 cases green twice", "46 files
  (26 `lua/`, 2 `ftplugin/`, 18 `tests/`)", "44 library entries": all four
  reproduce.

## Still open, unchanged by this review

§8.5 stands: no run has happened on a real runner, the caching decision waits
on those timings, and **D1 (push + PR) has not been done**. R1 says the first
run will not be clean; it is worth fixing before the push rather than
discovering it as the first red badge on a freshly public repo.
