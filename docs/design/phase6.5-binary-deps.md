# Phase 6.5 design: binary dependencies — declared here, resolved by the project

> Revision history
>
> * **r1** (2026-08-08) — four "tiers" of binary ranked by the consequence of a
>   wrong version. **Rejected**: at runtime a formatter is exactly a language
>   server.
> * **r2** (2026-08-08) — axis replaced with *whose dependency it is*: the
>   repo's own versus the user's.
> * **r3** (2026-08-09) — that axis, decided: a repo-local Mason under
>   `deps/`, provisioned by `just deps` against a pinned registry.
> * **r4** (2026-08-09) — **both halves of r3 rejected by the user, and the
>   phase gets much smaller.** (1) A `ucw.tools` list restating the nine
>   servers broke `ucw.lsp.servers`'s standing as the single source of truth
>   for LSP; the new list is the *complement*, and there is no new module at
>   all. (2) `deps/`-as-toolchain made ucw.nvim a special repo. **Any** repo
>   may pin its own formatter/linter/server, by any mechanism (mise, npm, uv,
>   nix), and the editor must prefer it — so the mechanism cannot be one this
>   repo invents for itself. The user also ruled out a resolver of our own
>   ("不应该自己做解析"): resolution is `PATH`, and the fix is a **one-line
>   change to who wins it**. What is left of r3 is one measured fact (§3.5)
>   and one deleted assumption.
> * **r5** (2026-08-11) — **as built**. Three of r4's measurements were wrong
>   and are corrected in place (`mise trust`, §2.3; the rustup component,
>   §2.2; the blast radius, §2.2). Two things landed that §2.5 did not
>   anticipate, both forced by the design rather than added to it: `just test`
>   has to *establish* the project environment (§2.3a), and doing so made a
>   `tree-sitter` CLI reachable from the test children for the first time, so
>   the automatic parser install grew the UI gate Mason already had (§2.3b,
>   user decision). §10 records what §5 asked for and what it found —
>   including the one prediction that came back the other way: a broken
>   binary on `PATH` fails **silently**.
> * **r6** (2026-08-12) — **accepted after review**, five findings fixed
>   (`docs/design/phase6.5-acceptance-review.md`, kept as the record of the
>   time and not rewritten). The one that changes behaviour is **R1**: §2.3b's
>   UI gate was the wrong half of Mason's rule and let the parser install
>   through under firenvim and vscode-neovim — corrected in place below,
>   because as written §2.3b describes a gate this repo no longer has. The
>   other four were false statements in code comments and contributor docs,
>   fixed where they lived. §11 records the outcome. 141 cases, green ×2.

---

## 0. Why this phase exists

`lua/ucw/` declares what an editing session needs; Mason installs whatever is
missing. That much already works. Two things do not:

* **`mason.setup()` prepends its `bin/` to `PATH`**, so the editor's
  *compatibility floor* wins over anything the project or the user chose.
  A repo that pins `prettier@3.2` in `node_modules`, or `stylua` in a
  `mise.toml`, or `ruff` in a `.venv`, is silently overridden by whatever
  Mason happened to install one day.
* **One binary is declared by nothing** (`rust-analyzer`, §3.1), which is how
  a 2022 copy survived the entire modernization.

Phase 7 (CI) is built on this phase — the user settled that on 2026-08-09 —
because three of its findings are downstream of the first bullet.

Goals served: **3** (reduce tech islands) and **10** (maintainable).
Goal 13 was Phase 6's and is complete. Numbered 6.5 because `phase7-ci.md`
and the plan file already reference Phases 7-10 by number.

---

## 1. The rule

**Declaration is machine-independent. Resolution belongs to the project.**

1. **What an editing session needs is declared in `lua/ucw/`**, and it never
   asks what this machine happens to have. Missing means *install it*, not
   *do without it*. That is already true and does not change.
2. **Mason is the floor, not the ceiling.** It exists so that a machine with
   nothing still gets a working language server. It must be the **last**
   thing consulted, never the first.
3. **Whatever the project provides wins**, through the mechanism that project
   already uses — `node_modules/.bin`, a `.venv`, a `mise.toml`, `nix
   develop`, `direnv`. All of them express themselves the same way: they put
   a directory on `PATH` ahead of everything else.
4. **ucw.nvim is not a special repo.** Its own `stylua` is project-local in
   exactly the sense a Node repo's `prettier` is, and it gets there by the
   same means. Nothing in `lua/ucw/` may contain the string `ucw.nvim`.

Rule 3 is the whole design, and it needs **no resolver of ours**. `PATH` is
the mechanism every one of those tools already targets; a bespoke provider
chain would be a second, worse implementation of it that every future
consumer would have to be taught about — the tech island goal 3 exists to
remove. So the change is not "add resolution", it is **stop overriding it**.

### 1.1 What this deliberately does not cover

`PATH` is process-global, so "the project" means *the environment nvim was
started in*, not the buffer under the cursor. A session launched without the
project's environment, or one that `:cd`s into a second project, gets the
floor. Two reasons to accept that rather than fix it:

* Fixing it means per-buffer resolution — our own chain, re-derived for
  conform, for `vim.lsp.config`, for rustaceanvim, and for every plugin
  added later. That is the island.
* Everything else on a developer machine behaves this way. `cargo`, `npm`
  and `python` all resolve from the environment they were launched in; an
  editor that invented its own answer would be the odd one out.

What the design owes in exchange is **visibility**: `:checkhealth ucw`
reports the path each declared binary actually resolves to (§2.4), so
"Mason's copy is being used here" is a thing you can see rather than
discover.

---

## 2. The design

### 2.1 Declaration: `ucw.lsp.servers` stays the source of truth

No new module, and nothing restates the nine servers.

* **`lua/ucw/lsp/servers.lua` — unchanged.** It remains the single
  registration point for LSP: one line still drives `vim.lsp.enable()`,
  mason-lspconfig's `ensure_installed`, and the `ft` trigger.
* **`lua/ucw/plugins/mason-lspconfig.lua` — unchanged**, and kept. r3
  proposed deleting it on the grounds that the `lspconfig name → package
  name` mapping is really the registry's (§3.4, still true). That argument
  counted the six lines of `invert()` and missed what they hide: the mapping
  is empty until the registry has been refreshed (measured), so replacing
  the plugin means reimplementing its refresh ordering too. It keeps its one
  job, and §3.4 stands as the note for whoever ever wants the exit.
* **`lua/ucw/plugins/mason-tool-installer.lua` — gains one entry.** It is
  already the declaration site for "binaries with no LSP counterpart", with
  a comment saying exactly that. `rust-analyzer` joins `stylua` and
  `prettier` there, under its own reason:

  ```lua
  ensure_installed = {
    'stylua',
    'prettier',
    -- Installed but deliberately never `vim.lsp.enable()`d. rustaceanvim
    -- starts this client itself; a second one is what used to attach twice
    -- to every Rust buffer, which is why `rust_analyzer` is absent from
    -- `ucw.lsp.servers`. For four years that absence also meant nothing
    -- installed it - this machine ran a 2022 build the whole time (§3.1).
    'rust-analyzer',
  },
  ```

That is the entire declaration change: **one line**. `prettier` stays
declared even though it cannot install here today — the declaration says what
an editing session needs, not what this machine has, and the day `npm` is
reachable it installs itself.

### 2.2 Resolution: Mason goes last

```lua
require('mason').setup { PATH = 'append' }
```

`"prepend"` is Mason's default (`mason/settings.lua:17`, applied at
`InstallLocation.lua:91-92`). Flipping it to `"append"` makes rule 2 true for
**every** consumer at once — conform's bare `command = 'stylua'`,
`vim.lsp.config`'s `cmd`, rustaceanvim's `exepath('rust-analyzer')`,
nvim-treesitter's `executable('tree-sitter')` — including consumers that do
not exist yet. Nothing has to opt in, and nothing has to know about a
resolver.

**Outside this repo the blast radius is exactly one tool**, measured by
resolving all twelve declared binaries under both orders:

| | prepend (before) | append (now) |
|---|---|---|
| the other 11 | Mason's | **identical** — nothing else is on this machine's bare `PATH` |
| `rust-analyzer` | Mason's 2022 build | `/usr/lib/rustup/bin/rust-analyzer` |

> **r5 correction.** That table describes a session started from a shell with
> no project environment, which is the general case and the one the number was
> about. *Inside this repo* — the environment `just` and a session started
> here get — §2.3's `mise.toml` moves four more: `stylua`, `ruff`, `taplo` and
> `lua-language-server` now resolve to the pinned copies instead of Mason's.
> That is the mechanism working, not a surprise, but "exactly one tool" would
> have been the wrong thing to remember. Measured after landing, with
> `:checkhealth ucw` (§2.4.1) as the instrument.

That one is not a regression the change introduces; it is a machine
misconfiguration the change *stops hiding*. `rustup` puts a shim on `PATH`
whether or not the component is installed:

```
$ /usr/lib/rustup/bin/rust-analyzer --version
error: Unknown binary 'rust-analyzer' in official toolchain 'stable-...'.   (exit 1)
```

`vim.fn.executable('rust-analyzer')` is nonetheless `1`, and rustaceanvim
gates on exactly that (`config/internal.lua`: `auto_attach` checks
`executable(cmd[1])`; `cmd` is `exepath_or_binary('rust-analyzer')`). So
before this phase, today's working Rust setup was an accident of Mason
shadowing a broken shim.

**Landing this phase therefore includes `rustup component add
rust-analyzer`** — one command, no sudo, and the result is strictly better
than what it replaces: a rust-analyzer matched to the toolchain that compiles
the code, chosen by the user's tool manager, exactly as rule 3 intends. Mason
keeps its copy as the floor for machines with no rustup. `:checkhealth ucw`
is what makes the switchover visible (§2.4).

> **r5 correction: already done, on the day r4 was written.**
> `rustup component list --installed` shows
> `rust-analyzer-x86_64-unknown-linux-gnu`, the shim answers
> `rust-analyzer 1.89.0 (2948388 2025-08-04)` with exit 0, and the binary at
> `~/.local/share/rustup/toolchains/stable-.../bin/rust-analyzer` is dated
> **2026-08-09 21:55**. So D5's one-off needed no action at landing time, and
> the switchover is live: opening a Rust buffer starts a client that
> initializes against rustup's copy (verified), where the same probe before
> this phase would have got Mason's Oct 2022 build.

### 2.3 ucw.nvim as an ordinary project

The repo's own development tools — `stylua` to check its Lua,
`lua-language-server` to lint it, `ruff`/`taplo` as real fixtures for
`tests/test_format.lua` — are **not a category**. They are one project's
pins, and they use the mechanism this machine already uses for project pins:
a checked-in `mise.toml`.

```toml
[tools]
stylua = "2.5.2"
lua-language-server = "3.18.2"
ruff = "0.16.2"
taplo = "0.10.0"
```

All four are in mise's registry via `aqua:` backends (§3.3). Consequences:

* **`just deps`** = `mise install` + the existing `mini.nvim` clone pinned to
  `lazy-lock.json` (Phase 7 D10, unchanged). No vendored `mason.nvim`, no
  second Mason root, no registry tag, no hand-written install loop — all of
  which r3 proposed and this deletes.
* **`just fmt` / `just fmt-check` / `just lint`** run `mise exec -- stylua …`
  / `… lua-language-server --check …`. They never touch
  `~/.local/share/nvim`, which is Phase 7's bare-runner contract, obtained
  here as a consequence rather than as a rule.
* **`tests/test_format.lua`** drops `REAL_MASON_BIN` and
  `use_real_mason_bin()`; the child inherits the project's tools like any
  other process. The *absent* case Phase 7 D8 specified is unchanged — it
  still strips the directory back off and asserts the loud no-op.
* **Reproducibility comes from the pin, not from the location.** r2 and r3
  conflated the two and built a repo-local install root to get it; `mise.toml`
  (plus `mise.lock` where available) pins versions while the store stays in
  the user's mise directory, which is where every other project's pins live.
* **The `stylua` seam disappears** instead of being reported. r3 spent a
  decision (its D6) on "editing this repo formats with the runtime `stylua`
  while CI checks with the dev one". Under rule 2 there is one `stylua` — the
  project's — for the editor, for `just`, and for CI.

Two operational facts about a checked-in `mise.toml`, both measured while
probing §7's mini.nvim question, and both of which `just deps` has to handle
rather than discover:

* ~~**A project config is untrusted until it is trusted.**~~ **r5: wrong, and
  the recipe is simpler for it.** mise loads a config that is plain `[tools]`
  with literal version strings *without* trust — `mise trust --help` says so
  outright ("Safe config files do not require trust… nothing in them executes
  code at load time"), and a scratch never-trusted config was measured
  resolving and installing fine on mise 2026.7.11. So `just deps` is
  `mise install`, a fresh checkout authorizes nothing, and CI needs no
  equivalent. What is load-bearing instead is a *constraint on the file*:
  adding tasks, templates or tool options would make trust matter again, so
  `mise.toml` carries a comment saying to keep it plain.
* **Project and global configs compose.** `mise install` inside the repo also
  installs whatever the user's `~/.config/mise/config.toml` declares —
  measured: a scratch run pulled in `node`, `tree-sitter` and
  `cargo-binstall` alongside the repo's own. That is the right behaviour (it
  is the same environment the editor will resolve through) and it is
  harmless on CI, where there is no global config; it is called out here so
  that "`just deps` installed something I never asked for" is documented
  rather than alarming. **r5: this one is not merely cosmetic** — composing in
  the global `tree-sitter` is what produced §2.3b.

### 2.3a `just` establishes the environment, it does not assume one

r4 said the test child "inherits the project's tools like any other process"
and left it there. Inheriting from *what* turns out to be the whole question:
a shell only has the project's tools if `mise activate` ran in it, and one
measurably had not (§3.3's caveat), while a CI runner has no shell profile at
all. `just deps` installing into mise's store puts nothing on `PATH`.

So every recipe that runs a binary runs it through `mise exec --`, including
`test`. That is not a second resolver — it is how a project environment is
entered non-interactively, and `mise exec` also installs a missing tool on the
spot, which is why only `deps` has to be run deliberately.

Reverse-verified (Phase 4's F5 rule): with the `mise exec` removed from the
`test` recipe, six cases in `tests/test_format.lua` go red on this machine —
so the recipe is what supplies the formatters, not the ambient shell.

### 2.3b The parser channel: an automatic install now needs a UI

Making the project environment real had one consequence nowhere in r4: the
global mise config's `tree-sitter` 0.26.11 (§3.3) composes in, so
`vim.fn.executable('tree-sitter')` became `1` **inside the test children** for
the first time in this project's history. `treesitter.lua`'s boot-time
`install(ensure_installed)` promptly started downloading and compiling grammars
into each integration file's scratch data directory — found as a red screenshot
assertion in `tests/test_fold.lua`, where the install popup had covered the
fold text it reads.

The fix (user's call, 2026-08-11) is the rule Mason already applies to its own
automatic installs, and which `tests/test_lsp.lua` already asserts as a
precondition: **nothing installs itself in a session with no UI attached.**
`nvim --headless`, a `-c` script and a mini.test child all boot in
milliseconds again; `:TSUpdate` and `:TSInstall` are untouched, and an
interactive session behaves exactly as before.

> **r6 correction: that was the wrong half of Mason's rule, and shipping only
> it was a live regression** (review R1). Mason's protection here is *two*
> layers: `mason-tool-installer.lua` and `mason-lspconfig.lua` carry
> `cond = is_full_ui`, so under an embedded target lazy never loads them at
> all, and Mason's own no-UI check — the half `tests/test_lsp.lua` asserts —
> only ever applies underneath that. nvim-treesitter has no `cond` (it is
> `lazy = false` on purpose, the embedded targets want its highlighting), so
> the inner half alone was not enough: **firenvim and vscode-neovim each
> attach a UI of their own** (`nvim_ui_attach`, to receive the redraw events
> they paint into the browser textarea / the VS Code editor), which made
> `#nvim_list_uis() > 0` true in exactly the two contexts this config keeps
> automatic installs out of. Measured: a firenvim-marked session with a
> reachable CLI invoked it 1.9 s after boot returned. The gate is now
>
> ```lua
> if #vim.api.nvim_list_uis() > 0 and require('ucw.targets').is_full_ui() then
> ```
>
> and neither conjunct is redundant — dropping the first re-opens the headless
> case this section was written for, dropping the second is the bug.
> **`nvim_list_uis()` answers "a UI is attached", not "a human is present";
> contexts are what `ucw.targets` is for.** `tests/test_treesitter.lua`'s
> `embedded contexts` group covers it with a real second Neovim and a
> genuinely attached UI, plus a full-UI positive control.

Two things worth keeping:

* This is not new fragility, it is old fragility becoming reachable. The suite
  was protected only by "no `tree-sitter` exists anywhere on this machine" —
  the same accident `phase7-ci.md` §5 calls out as matching "by luck rather
  than by design". A CI runner that happened to ship the CLI would have hit it
  with no change of ours at all.
* It does **not** close §9's carried-forward item. What an *interactive*
  session does the first time a `tree-sitter` CLI is reachable is still
  unverified, and still wants its own look.

`tests/test_treesitter.lua` covers the gate with a fake `tree-sitter` on the
child's `PATH`, so the case is discriminating on a machine that has no real
one; reverse-verified by removing the gate (the boot then emits
`nvim-treesitter/install/...: Downloading ...`).

> **r6**: that file now also carries the `embedded contexts` group R1 needed,
> and it is worth knowing why it is built differently. The no-UI case above can
> assert on the *effect* (no parser directory) because a mini.test child has no
> UI and therefore nothing to race. The embedded cases cannot: they need a UI
> genuinely attached, which the mini.test child cannot have, so they drive a
> second Neovim over RPC — and there the install is asynchronous, so asserting
> the effect immediately is a dud that passes with the gate removed (it did,
> once). They watch whether `require('nvim-treesitter').install` is **called**
> instead, recorded by wrapping the global `require` before `ucw.boot()`; the
> booting `nvim_exec_lua` is a blocking request and `config()` runs inside it,
> so the counter is final the moment it returns.

### 2.4 `:checkhealth ucw`

A new `lua/ucw/health.lua`. It owns no policy; it reports four things, and
its whole purpose is to make §1.1's accepted limitation visible:

1. **What each declared binary resolves to.** `exepath()` per entry, labelled
   by source (project/`PATH` vs Mason's floor). This is the line that would
   have shown `rust-analyzer` coming from Mason since 2022, and the line that
   shows a project's pin *not* being picked up in a session started from the
   wrong place.
2. **Declared versus installed, in three states**: declared-but-absent
   (`prettier` here, with the reason and what changes when `npm` appears),
   installed-but-undeclared (what `rust-analyzer` was), and
   **installed-but-behind** — because neither runtime installer ever updates
   an already-installed package (§3.2), so "this binary is four years old"
   has to be someone's job to notice.
3. **`tree-sitter`**, whose absence blocks parser installs. The one-shot
   probe in `treesitter.lua` stays where it is: it exists to suppress a
   per-boot error, which a health check cannot do.
4. **A pointer to `:checkhealth mason`** for system prerequisites — `curl`,
   `unzip`, `tar`, `node`, `npm`, `python`, `java`, `cargo` and more are
   already checked there, maintained upstream (§3.6). Writing a second,
   smaller version of that list was r3's D7 and is dropped.

No gate hangs off any of it: `:checkhealth` exits 0 with a hard ERROR in it
(measured), and a CI runner has no user Mason directory to check anyway.

### 2.5 What changes

| File | Change |
|---|---|
| `lua/ucw/plugins/mason.lua` | `setup { PATH = 'append' }` — the whole of §2.2 |
| `lua/ucw/plugins/mason-tool-installer.lua` | `+ 'rust-analyzer'` and its comment |
| `lua/ucw/lsp/servers.lua` | untouched; a pointer comment for where install-only servers go |
| `lua/ucw/plugins/mason-lspconfig.lua` | untouched (§2.1) |
| `lua/ucw/health.lua` | **new** |
| `mise.toml` | **new**, checked in (§2.3) |
| `justfile` | `deps` gains `mise install` (§2.3); every tool-running recipe goes through `mise exec` (§2.3a); new `fmt`, `fmt-check`, `lint` |
| `tests/test_format.lua` | `REAL_MASON_BIN` deleted |
| one-off, outside the repo | `rustup component add rust-analyzer` |

Landed in addition (r5), each one forced by something above rather than
chosen alongside it:

| File | Change | Why it is here |
|---|---|---|
| `lua/ucw/plugins/treesitter.lua` | automatic parser install gated on a UI | §2.3b |
| `tests/test_treesitter.lua` | **new**, 2 cases | covers that gate |
| `tests/test_health.lua` | **new**, 8 cases | §2.4 is a report, and an unread report is not a compensation |
| `tests/aux/lua/helpers.lua` | `boot_embedded` extracted from `tests/test_format.lua` | two files now need to boot an embedded target for the same reason |
| `tests/test_format.lua` | `PATH order` group; the `lsp_format` cases strip `PATH` explicitly | the project's formatters are reachable now, so "unchanged buffer" had stopped being evidence |

`just lint` lands as a *tool*, not a gate: without Phase 7's `.luarc.json` it
runs against lua_ls's bare defaults and reports 472 problems (~20 real,
triaged in `phase7-ci.md` §1.5). `just fmt-check` is red for the reason
§1.4 there already gives. Both are recipes this phase owes Phase 7, not
promises this phase keeps.

---

## 3. What this rests on (measured 2026-08-08/09)

### 3.1 The orphan

Declared versus `~/.local/share/nvim/mason/packages/`: 10 declared and
installed, `prettier` declared and absent, and one **installed, declared by
nothing** — `rust-analyzer 0.3.1248-standalone`, `Oct 22 2022`. Phase 3
removed `rust_analyzer` from `ucw.lsp.servers` on purpose; what went
unnoticed is that `ensure_installed` was also the only thing *installing* it.
Both directions were broken — a four-year-old binary here, and none at all on
a fresh machine — and nothing could notice, because the declared set and the
installed set were never compared (§2.4.2).

### 3.2 Nothing on the runtime side updates by itself

`mason-tool-installer/init.lua:35-36`: `auto_update = false`,
`run_on_start = true`; the update branch (`:289`, `:324`) is reached only
under `force_update` or an explicit `auto_update`, so an already-installed
package is skipped without ever consulting `get_latest_version()`.
mason-lspconfig's `ensure_installed` behaves the same way.

So the four-year-old `rust-analyzer` is not a symptom of being *undeclared* —
it is **the steady state of every declared package**. Declaring it in §2.1
fixes fresh machines and does *not* by itself replace the copy on this one;
that is what §2.4.2's third state exists to surface, and one reason §2.2's
`rustup` switchover is worth doing rather than deferring.

### 3.3 This machine already manages tools with mise — for this config's sake

`mise 2026.7.11` is installed, and its **global** config declares tools that
the nvim config believes are absent:

| declared in `~/.config/mise/config.toml` | on disk | what the nvim config says |
|---|---|---|
| `node = "25"` | `node v25.9.0`, `npm 11.12.1` | `servers.lua`: jsonls "needs `node` … absent here"; Phase 6: `prettier` uninstallable |
| `tree-sitter = "latest"` | `tree-sitter 0.26.11` | `treesitter.lua` warns every boot; docs say `cargo install tree-sitter-cli` |

The mise config's own comment names the motive: *"Node was installed but
pinned nowhere, so every shim failed … anything needing npm was unusable —
notably Mason's npm-backed language servers … **for the Neovim config**"*
(yadm commit `326f359`; `tree-sitter` added in `06f5c5d`, 2026-08-04 21:35).
And Mason still failed to install `prettier` with
`Could not find executable "npm" in PATH` on **2026-08-05 22:42** — the day
after.

So the tools were provisioned, deliberately, for this editor, and the editor
never saw them. That is rule 3 stated as a bug report, and it is why the
mechanism has to be `PATH` rather than anything this repo invents.

*Caveat worth checking in a real terminal:* `~/.config/zsh/extra.d/mise.zsh`
does run `mise activate zsh`, but no shell reachable from here shows a single
mise entry on `PATH` (`zsh -i -c` and `zsh -l -i -c` both give zero). If that
reproduces interactively it is a dotfiles bug, not an nvim one, and it is
outside this phase — but it is the reason §2.4.1 reports resolved paths
instead of assuming them.

> **r5: checked in a real terminal, and it is worse than "no mise entries".**
> A login+interactive `zsh` on this machine has a **five-entry** `PATH`:
>
> ```
> ~/.local/share/zsh/zinit/polaris/bin : /usr/local/bin : /usr/bin
> : ~/.local/bin : ~/.local/share/cargo/bin
> ```
>
> No mise, and also no `/usr/local/sbin`, no `/usr/bin/{site,vendor,core}_perl`,
> no `/usr/lib/rustup/bin`, no `~/.local/share/krew/bin` — all of which *are*
> present in the environment this session's own shell inherited, and in the
> tmux server's global environment. So something in the zsh startup is
> **assigning** `path` rather than extending it. A real Neovim TUI launched
> from that shell was confirmed to have exactly that `PATH` plus Mason's
> appended bin dir, read straight off `:checkhealth ucw`.
>
> Two consequences worth stating plainly, because they decide what this phase
> is actually worth *today*:
>
> * **The mechanism is correct and currently delivers nothing here.** An
>   interactive session started inside this repo does not see `mise.toml`'s
>   pins, because the shell it inherits from cannot see them either. `just`
>   does (it calls `mise exec` itself, §2.3a), which is why the suite runs on
>   the pins and the editor does not.
> * **`rust-analyzer` still comes from Mason's Oct 2022 build in real use** —
>   not because Mason wins, but because `/usr/lib/rustup/bin` is not on that
>   `PATH` at all. §2.2's switchover is real wherever rustup's shims are
>   reachable; it is not reachable from a terminal-launched editor here.
>
> Still a dotfiles bug and still §9's non-goal — but it is now a *known* one
> with a measurement attached, rather than a caveat to check. It is also the
> single highest-value thing anyone could fix next, since it is what stands
> between this phase's mechanism and its effect.
>
> > **r6 sharpening, and the thing to actually go looking for.** That
> > five-entry `PATH` is **not** missing `mise`: its first entry,
> > `zinit/polaris/bin`, contains a working `mise` wrapper, and `zsh -c
> > 'command -v mise'` resolves it (while the same `PATH` into `bash` finds
> > nothing — the zinit wrappers are zsh scripts, so any zsh start re-derives
> > them). What is missing is **`mise activate`'s injection of the tool
> > paths**. So the bug is not "mise never loads", it is "something assigns
> > `path` *after* activate and discards what it added" — which is the same
> > shape as `/usr/local/sbin`, the perl dirs, `/usr/lib/rustup/bin` and krew
> > all vanishing, and it narrows the search to what runs after activate
> > rather than to activate itself.
> >
> > The same wrapper mechanism is why §5's "remove mise from `PATH` and
> > confirm `just deps` fails loudly" leg is un-runnable here short of a
> > container: `just` is itself a `#!/usr/bin/env zsh` zinit wrapper, so it
> > launders the caller's environment through a fresh zsh and gets `mise`
> > back every time. `phase6.5-acceptance-review.md` §2 has the measurement.

### 3.4 The name mapping is the registry's, not mason-lspconfig's

`mason-lspconfig/mappings.lua` builds its map by inverting each registry
package spec's `neovim.lspconfig` field. Six lines of direct registry
iteration reproduce it exactly — 287 entries, byte-identical, 3.9 ms against
8.6 ms — **but only after `mason.setup()` and a refresh**; before that
`get_all_package_specs()` is empty and every server maps to `nil`, silently.
That second half is why §2.1 keeps the plugin.

### 3.5 mise covers the dev tools, and not the servers

`mise registry`: `stylua`, `lua-language-server`, `ruff`, `taplo`,
`marksman`, `rust-analyzer` are present (`aqua:` backends);
`basedpyright`, `clangd`, `json-lsp`, `ltex-ls-plus`, `texlab` are **not**.
Five of eleven. That is the whole reason Mason stays the floor (§1 rule 2)
rather than being replaced by mise, and the reason §2.3's `mise.toml` lists
exactly the four tools the repo needs for itself.

### 3.6 `:checkhealth` is already a prober, and still not a gate

Run here, `:checkhealth mason` reports `unzip`/`curl`/`gzip`/`tar`/`bash`/
`python`/`venv`/`cargo` OK and `wget`/`node`/`npm`/`java`/`javac`/`go`/
`luarocks`/`ruby`/`php`/`julia`/`pip` missing, plus the registry version —
every system prerequisite r3's D7 would have hand-listed. (Its `node`/`npm`
warnings agree with §3.3: mise has them, this environment does not.)

It is still the wrong gate: a health provider whose `check()` only calls
`vim.health.error()` makes `nvim --headless -c 'checkhealth …'` exit **0**.

Two things checked rather than assumed: `ltex-ls-plus` ships its own JDK 21
and needs no system `java`; and `json-lsp` is installed but cannot run
without `node`, a state no pin or declared/installed check would catch —
§2.4.1's resolved-path report is the closest thing, and `:checkhealth mason`
is the generic signal.

---

## 4. Decisions

* **D1 — `ucw.lsp.servers` stays the source of truth for LSP.** The
  install-only complement lives where the complement already lives
  (mason-tool-installer's `ensure_installed`), not in a list that restates
  the servers (§2.1).
* **D2 — `PATH = 'append'`.** One line; measured blast radius of one tool
  (§2.2).
* **D3 — No resolver of our own** (user: "不应该自己做解析"). `PATH` is the
  mechanism; §1.1 states the limitation this accepts and §2.4.1 is the
  compensation.
* **D4 — No repo-local install root.** ucw.nvim uses `mise.toml` like any
  project (§2.3). r3's `deps/xdg` Mason, vendored `mason.nvim` and pinned
  registry tag are all dropped.
* **D5 — `rust-analyzer` is declared to Mason** (user), *and*
  `rustup component add rust-analyzer` is part of landing the phase (§2.2).
* **D6 — `prettier` stays declared** (user: "没有就自动装"). Its dormancy is
  a fact about this machine, not a decision to encode; `ftplugin/markdown.lua`
  is untouched and markdown starts formatting on save whenever `npm` becomes
  reachable.
* **D7 — No prerequisite prober**; `:checkhealth mason` already is one
  (§3.6).
* **D8 — No registry pin at runtime, and no `auto_update`.** Silently
  swapping a language server under a running editor is worse than an old one;
  updating stays deliberate, and §2.4.2's third state keeps "deliberate" from
  meaning "forgotten" (§3.2).

---

## 5. Verification plan

Per the Phase 4 F5 rule, each mechanism is broken on purpose:

* **`append` actually reorders.** Put a deliberately distinguishable
  `stylua` earlier on `PATH` and confirm conform runs *that* one; remove it
  and confirm the run falls back to Mason's. A test that passes under both
  orders proves nothing.
* **The rust-analyzer switchover, both states.** Before
  `rustup component add`: confirm the failure is *loud* — a client that
  cannot start, not a silent no-attach (Phase 3's P4 is the precedent for
  that being possible). After: confirm the client attaches and reports the
  toolchain version.
* **The project's tools are what the suite runs.** Run the whole suite with
  `~/.local/share/nvim/mason` renamed away; it must stay green. This is the
  only real proof that `just`/`tests/` stopped reading the user's Mason.
* **`mise.toml` is load-bearing.** Change a pinned version and confirm
  `just fmt-check` behaviour changes with it; remove `mise` from `PATH` and
  confirm `just deps` fails loudly rather than silently falling through to a
  system binary.
* **The health check discriminates, all three states** (§2.4.2): remove a
  package from the declaration while it stays installed; add one that is not
  installed; hold one behind the registry. Red all three times — the middle
  one is what four years of `rust-analyzer` needed, and the third is what
  §3.2 means it *still* needs after being declared.
* **The absent-formatter cases can still fail** (Phase 7 D8's own rule):
  drop the `PATH` strip and they must go red.
* The whole suite **twice**, per "green once is not a signal" (Phase 3 P7).

---

## 6. Risks

* **`append` inverts a default that upstream chose deliberately.** Mason
  prepends so that its copies win; making them lose means any broken or stale
  same-named binary on `PATH` now wins instead. Today that is exactly one
  case and it is a real misconfiguration (§2.2) — but the next one will
  arrive without warning, and §2.4.1 is the only thing that will show it.
* **Rust editing changes twice in one phase**: from a 2022 Mason build to a
  current rustup one. Its own commit, so anything odd is attributable.
* **`mise` becomes a hard dependency of `just`.** It is already installed and
  already used on this machine, and CI installs it in one step — but it is a
  second tool the contributor instructions have to name, where before there
  was only `nvim` + `git` + `just`.
* **§1.1's limitation will bite someone eventually**: a session started from
  the wrong directory quietly formats with the floor. The mitigation is a
  health check nobody runs unprompted. If this turns into a real problem,
  the honest fix is per-buffer resolution — and re-reading D3 with a concrete
  failure in hand is a better decision than pre-emptively building it.
* **`prettier` will activate itself.** D6 keeps the declaration, so the first
  time `npm` is reachable, markdown starts being reformatted on save — a
  behaviour change triggered by an unrelated environment fix. §2.4.2 names it
  in advance; nothing enforces that anyone read it.

---

## 7. Alternatives rejected

* **A repo-local Mason under `deps/`, pinned by a registry tag** (r3). It
  works — measured: one env var (`XDG_DATA_HOME=deps/xdg`) puts Mason's whole
  layout in the repo, 83 MB cold in 2-6 s, 0.01 s and zero network warm, and
  moving the tag backwards genuinely downgrades. Rejected because it solves
  the problem *for this repo only*, and every other repo the user edits has
  the same problem.
* **A provider chain of our own** (`node_modules/.bin` → `.venv/bin` →
  `mise which` → `rustup which` → `PATH` → Mason), wired into conform,
  `vim.lsp.config` and rustaceanvim. Rejected as a tech island: a second
  implementation of `PATH`, which every future consumer would have to be
  taught. Recorded because §1.1's limitation is precisely what it would have
  bought, if that limitation ever proves expensive.
* **Replacing Mason with mise entirely.** Six of eleven declared binaries
  have no mise backend (§3.5).
* **Letting mise manage `deps/mini.nvim` too**, so `just deps` would have one
  mechanism instead of two. It **works** — measured, with no plugin to write:

  ```toml
  "http:mini.nvim" = { version = "946ae64e…", url = "https://github.com/echasnovski/mini.nvim/archive/946ae64e….tar.gz" }
  ```

  installs cleanly, strips GitHub's top-level archive directory, and
  `mise where http:mini.nvim` lands on a tree with `lua/mini/test.lua` in
  place. Rejected for three reasons, in order of weight:

  1. **It splits a pin that is about to be unified.** Phase 7 D10 takes
     `deps/mini.nvim`'s revision from `lazy-lock.json`'s `mini.nvim` entry —
     one pin, and the harness tracks the revision the config actually uses.
     Moving it into `mise.toml` creates a second hand-maintained SHA for the
     same plugin, free to drift from the first. That is the exact failure
     class this phase exists to remove, traded for one line of `justfile`.
  2. **Wrong domain.** mini.nvim is a Neovim plugin that is only ever
     appended to `rtp`. Everything mise is good at — `PATH`, shims,
     per-project resolution of *executables* — is inapplicable, so what is
     left is using a tool manager as a generic tarball cache. Meanwhile the
     repo already runs a plugin manager with a lockfile.
  3. **The path stops being static.** `tests/aux/driver_init.lua` currently
     appends a literal `getcwd() .. '/deps/mini.nvim'`, and its own comment
     says it "intentionally does nothing and loads no dependencies". Under
     mise it must shell out to `mise where` on every driver start, or
     hardcode a path inside someone's mise store.

  A fourth, weaker point worth knowing: `/archive/<sha>.tar.gz` is generated
  on demand rather than being a release asset, and its bytes are not
  guaranteed stable over time, so a recorded `mise.lock` checksum can fail
  for reasons unrelated to the content. `git fetch <sha>` is
  content-addressed by construction. (Adjacent to the `/archive/` URL
  problem already hit once with the vfox plugins.)

  The line this settles: **pins live in the manager that understands the
  artifact.** Lua plugins — runtime and test harness alike — are pinned by
  `lazy-lock.json`; binaries are pinned by `mise.toml`. Two managers for two
  kinds of thing is a domain boundary, not an island.
* **Deleting `mason-lspconfig.nvim`** (r3). The mapping is registry data
  (§3.4), but the plugin also hides the refresh ordering that makes it
  non-empty.

---

## 8. What this changes in `phase7-ci.md`

Phase 7 moves to r4 on top of this; these are subtractions:

* **§1.2 / D8 / §3.4** — `REAL_MASON_BIN` and `use_real_mason_bin()` go away,
  and D8's per-run in-child formatter install collapses into `just deps`.
  The present/absent axis it introduced survives unchanged.
* **§3.1** — `just lint`'s "resolve the binary from Mason's bin dir" was a
  second, uncounted reach into the user's data dir; it becomes `mise exec`.
* **§3.2 / §5** — the `format` job drops `JohnnyMorganz/stylua-action` for
  `just fmt-check`, restoring §3.1's "the workflow only calls `just`"
  invariant and deleting the `stylua` skew risk rather than mitigating it.
* **§1.2's "CI has `npm` and this machine does not"** is false (§3.3) and
  needs rewriting wherever it is load-bearing.
* The bare-runner contract becomes checkable: `checkout` + `nvim` + `just` +
  `mise`, then `just deps`.

---

## 9. Non-goals, and carried forward

**Non-goals.** Replacing Mason; managing `nvim` itself; the treesitter parser
channel (already fully pinned — `nvim-treesitter/parsers.lua` gives every
parser an exact grammar revision, compared against
`<data>/site/parser-info/<lang>.revision` before reinstalling, so parser
versions are transitively pinned by `lazy-lock.json`); Renovate/Dependabot;
anything CI-side, which stays Phase 7's; and the user's shell configuration,
even though §3.3 found something worth looking at there.

**Carried forward.**

* The `blink.cmp` popup in a freshly opened `.lua` buffer with no keypress
  (Phase 6 r4, user-confirmed real 2026-08-06). Unrelated, still unfixed.
* `williamboman/mason.nvim` and `williamboman/mason-lspconfig.nvim` are now
  redirects to the `mason-org` organisation; the specs still name the old
  owner. Harmless, worth a line whenever those files are next touched.
* Once `tree-sitter` is reachable (§3.3), `treesitter.lua`'s warning and the
  parser-install path both change behaviour for the first time in this
  project's memory. That is a *good* change and an unverified one; it wants
  its own look, not a footnote in this phase. **r5: still carried forward,
  and now half-answered.** §2.3b settled what a *headless* session does
  (nothing, like Mason). What an interactive one does the first time it can
  compile — how long, how loud, and whether `ensure_installed` is still the
  right list after four years of never running — is untouched. Note also that
  this machine's shell does not currently put mise's `tree-sitter` on `PATH`
  at all (§3.3's caveat), so the interactive change has not actually happened
  here yet; whoever fixes the shell triggers it.
* **A live breakage this design work caused, and repaired.** The r2 session
  drove `mason-tool-installer` with `location =` against the user's real
  Mason; it **uninstalled the global `stylua`** and installed nothing
  (`mason.log`, 2026-08-08 23:53:45). For a day, `format_on_save` on every
  Lua file was a warn-once no-op. Reinstalled 2026-08-09 (`stylua 2.5.2`,
  verified on disk).

---

## 10. As built: what §5 asked for, and what it found (r5, 2026-08-11)

138 cases across 15 files, **green twice**, `lazy-lock.json` unchanged after
both runs.

| §5 asked | Result |
|---|---|
| `append` actually reorders | **Yes**, and reverse-verified two ways. A marker-printing `stylua` earlier on `PATH` is the one conform runs; removing it brings the real one back. Flipping the spec to `prepend` turns the structural case red and leaves the behavioural one green — which is exactly why both exist (the child's Mason is empty, so `prepend` shadows nothing there). |
| the rust-analyzer switchover, both states | The "after" state works where rustup is reachable — verified: a client initializes against rustup's 1.89.0 build. **It is not reachable from a terminal-launched editor on this machine** (§3.3's r5 note), so real sessions still get Mason's 2022 copy until the shell's `PATH` is fixed. The "before" state no longer exists — the component was added 2026-08-09 (§2.2) — and re-creating it means uninstalling a user's toolchain component, so it was simulated with a broken shim instead. **The prediction was wrong: the failure is silent, not loud.** 0 clients, nothing in `:messages`, the stderr only in `~/.local/state/nvim/lsp.log`. Phase 3's P4 shape exactly. §6's first risk is therefore un-mitigated except by §2.4.1, which is now the only thing that would show it. |
| the project's tools are what the suite runs | **Yes**, and proved by removing the mechanism rather than by renaming the user's Mason directory: without `mise exec` on the `test` recipe, six cases go red. The suite never had `~/.local/share/nvim/mason/bin` on `PATH` in the green runs — no reference to it survives in the repo. |
| `mise.toml` is load-bearing | Partly. `mise exec` resolves the pinned copies (checked per binary), and `ruff` moving 0.16.0 → 0.16.2 is visible in `:checkhealth ucw`. The "remove mise from `PATH` and confirm `just deps` fails loudly" leg was not run: `mise` is on `PATH` by construction here and `just` reports a missing command as a non-zero exit anyway. |
| the health check discriminates, all three states | **Yes**, all three plus the OK state, as offline fixtures rather than real installs (`is_installed()` is a directory stat; the version comes from `mason-receipt.json`). Two cases also assert the *absence* of the other states' lines, because four cases each asserting one string would all pass against a report that printed all four. |
| the absent-formatter cases can still fail | **Yes**: dropping the `PATH` strip makes `lua stays unformatted` go red, because the project's `stylua` formats it. That case had been passing for a reason that no longer holds, which is why it is now paired with an explicit "formatter present" twin. |
| the whole suite twice | Done, green both times. |
| *(not asked for, and the most useful result)* | `:checkhealth ucw` run in a **real TUI**, which is the only place the editor's actual `PATH` can be seen. It reported every binary resolving to Mason — including the four this repo pins — and that is how §3.3's shell bug stopped being a caveat and became a measurement. The report earned its keep on its first real run. |

**Two bugs this phase's own code shipped into the working tree and then had
to fix — both are the seams these reviews keep finding, not new shapes:**

* `lua/ucw/health.lua` walked straight into **§3.4**: it built the
  `lspconfig name → package name` map *before* `registry.refresh()`, and
  mason-lspconfig memoizes that map from an empty registry without complaining.
  Every declared server reported "maps to no Mason package". It looked correct
  in seven of eight test cases, because the second case in a file reuses the
  first one's registry download — order dependence hiding a real defect, which
  is the thing `phase7-ci.md` §3.4 warns must never be relied on.
* The same file `require`d `mason-lspconfig.mappings` unconditionally, which is
  `cond`-gated off under the embedded targets: `:checkhealth ucw` under
  vscode-neovim was a Lua traceback. **Identical to Phase 6's R1**, in a file
  written by someone who had just read R1. The fix is the same one: report
  module availability, do not ask `ucw.targets` what context this is — the
  gate has one owner and it is the spec.

---

## 11. Accepted (r6, 2026-08-12)

`docs/design/phase6.5-acceptance-review.md`, five findings, all fixed.
**141 cases, green ×2.**

The review's own summary of the shape, which is the part worth carrying
forward: **every finding was downstream of one sentence** — §2.3b's "nothing
installs itself in a session with no UI attached" — borrowed from Mason
without checking that Mason's version of the rule has a second layer this one
did not. R1 is that gap in code; R3 is the document that would have revealed
it and instead asserted the opposite.

| # | Finding | Fixed in |
|---|---|---|
| R1 | the parser install fires under firenvim/vscode-neovim — both attach a UI | `lua/ucw/plugins/treesitter.lua` + 3 cases in `tests/test_treesitter.lua` (§2.3b's r6 note) |
| R2 | `docs/testing.md` documents the test command without `mise exec --` — 7 red of 15 if followed | `docs/testing.md` |
| R3 | `docs/testing.md`: the mini.test child "has a real UI attached, which is what makes screenshots possible" — false on both halves | `docs/testing.md` |
| R4 | `ufo.lua` argues from "this machine has no `tree-sitter` CLI", which §3.3 disproved | `lua/ucw/plugins/ufo.lua` |
| R5 | `tui-observation.md`'s worked example: Phase-1-deleted file, Phase-1-deleted log, a parser no longer declared, and "not via mise" | `docs/tui-observation.md` |

Two things the review settled that this document had left open:

* **§5's last unrun leg is not closed, and now cannot be here.** `just` is a
  `#!/usr/bin/env zsh` zinit wrapper, so it re-derives a `mise`-bearing `PATH`
  no matter what the caller passes. Worth more than the leg: the same probe
  showed the five-entry `PATH` of §3.3 *does* contain a working `mise`, so the
  dotfiles bug is specifically that **`mise activate`'s tool paths get
  discarded**, not that mise never loads. See §3.3's r6 sharpening.
* **The r5 "as built" claims re-verified**, including the ones r5 was
  correcting r4 about: the rustup component is installed and current
  (`rust-analyzer 1.89.0`, binary dated 2026-08-09 21:55), `just deps` needs
  no `mise trust`, and `just fmt-check`/`just lint` are red for the documented
  Phase 7 reasons only.

**Still open, and now with one more reason to care.** §3.3's shell `PATH` bug
remains the single highest-value thing to fix next. R1 adds a wrinkle for
whoever does: making `tree-sitter` reachable is also the moment §9's
carried-forward item — what an *interactive* session does the first time it
can compile — stops being hypothetical, and it will now happen only in a
full-UI session, which is the intended place for it to happen.
