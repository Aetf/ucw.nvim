# Phase 3 acceptance review

Reviewed: commits `2648576` ("Phase 3: replace the LSP hook framework with
Neovim's native config layers") and `cd8dde7` ("pyright -> basedpyright, and
record the as-built numbers") against `docs/design/phase3-lsp-redesign.md` (r3)
and the plan file's Phase 3 section. Phase 4 landed on top of this, so the
review is against the tree at `a94b9fe`.

**Verdict: do not accept as-is.** Three defects that are live today (P1, P2,
P3), one latent fragility the phase introduced (P4), a documentation gap the
phase convention asks for (P6), and a flaky test that makes `just all` an
unreliable acceptance signal for this phase and every one after it (P7). The
architecture itself re-measured sound: every claim in §1-§4 of the design
document that could be re-run, was, and holds — see §2 below.

Same rule as the design documents: everything marked *measured* was produced on
this machine, Neovim 0.12.3, against the real config, via `just all` / `just
ci`, `scripts/tui-drive.sh`, and mini.test probes. Nothing below is inferred
from reading the diff alone; where a measurement is indirect that is said
explicitly.

---

## 1. Findings

| # | Finding | Kind | Severity |
|---|---|---|---|
| P1 | `<leader>lI` toggles the **global** inlay-hint flag while `attach.lua` sets the **buffer** one: first press does the opposite of what it says, and the "off" state does not survive opening another file | regression-shaped defect, live | **major** |
| P2 | A `.vscode/settings.json` reload recomputes settings from a snapshot taken *before* `ltex_dict` ran, silently dropping every dictionary / false-positive / disabled-rule entry | defect introduced by this phase, live | **major** |
| P3 | `g[` / `g]` (prev/next diagnostic) are not mapped at all — the which-key v3 entry puts the rhs in `desc` | dead keybinding, live since Phase 1 | medium |
| P4 | `rustaceanvim` needs Mason's `PATH` edit to find `rust-analyzer` but declares no dependency on `mason.nvim`; it works today only because rustaceanvim itself `require`s `mason-registry` for an unrelated codelldb probe | latent fragility introduced by this phase | medium |
| P5 | Nothing runs on `LspDetach`: buffer-local keymaps, `<leader>a` and the `.vscode` file watchers outlive the client that created them | pre-existing, not a regression | minor |
| P6 | The design document has no as-built verification section (Phase 4's §6a); §4/§5 still describe two things that were deliberately built differently | process / documentation gap | medium |
| P7 | `tests/test_comment.lua` races the treesitter injection parse — `just all` was **red on the first run of this review** and green on the second | test-infrastructure defect (Phase 4 file, phase-agnostic impact) | medium |
| P8 | `:checkhealth vim.lsp` reports three "Unknown filetype" warnings caused by `servers.lua` mirroring upstream exactly | cosmetic, worth recording | trivial |

### P1 — the inlay-hint toggle is off by one, and does not stick

`attach.lua:61` enables hints for the **buffer**:

```lua
vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
```

`actions.lua:71` + `actions.lua:101-104` toggle the **global** flag, because
`M.call` passes no filter:

```lua
toggle_inlay_hint = { desc = 'Toggle inlay hints', lsp = 'inlay_hint.enable', toggle = true },
...
local is_enabled = M.resolve(action.lsp:gsub('%.enable$', '.is_enabled'))
return fn(not is_enabled())
```

Upstream keeps those in two places: `is_enabled(filter)` with `filter.bufnr ==
nil` returns `globalstate.enabled`, which starts `false` and is *only* written
by `enable()` calls that also pass no filter
(`runtime/lua/vim/lsp/inlay_hint.lua:384`, `:413`). A per-buffer `enable`
never touches it.

**Measured, real TUI, `lua/ucw/lsp/init.lua` with `lua_ls` attached:**

| step | `is_enabled{bufnr=0}` | `is_enabled()` | what the user sees |
|---|---|---|---|
| after attach | `true` | `false` | hints on |
| `<leader>lI` (1st) | `true` | `true` | **nothing turns off**; hints turn *on* in every other loaded buffer |
| `<leader>lI` (2nd) | `false` | `false` | hints off |
| then `:edit` another `.lua` file | `true` | `false` | **hints are back** |

The last row is the second half of the problem: `LspAttach` re-enables
unconditionally, so a user preference expressed with the bound key is undone by
the next attach.

This is also where the design document and the build disagree (see P6). §5
says, verbatim: *"this phase adds the `supports_method` guard and a named toggle
action in `keys/actions.lua`, but **does not bind a key to it** — Phase 9 places
it."* As built: there is no `supports_method` guard (deliberately, and
`attach.lua:53-60` argues the case well — but only in code, not in the
document), the table is `ucw/lsp/actions.lua`, and the key **is** bound at
`<leader>lI`. Binding it is what turned an untested action into a user-visible
defect.

**Fix**: scope the toggle to the buffer, which is the scope everything else in
`attach.lua` uses —

```lua
toggle_inlay_hint = {
  desc = 'Toggle inlay hints',
  lsp = 'inlay_hint.enable',
  toggle = { bufnr = 0 },   -- filter, passed to *both* is_enabled and enable
},
```

(`M.call`'s toggle branch changes with it: `fn(not is_enabled(filter), filter)`
instead of `fn(not is_enabled())`.)

— and decide separately whether attach should re-enable over an explicit
"off" (remembering it globally is the smaller change; `attach.lua` would call
`enable(vim.lsp.inlay_hint.is_enabled(), { bufnr = bufnr })` only when the user
has never touched it).

**Test gap**: `tests/test_lsp_actions.lua` asserts every action's `lsp` path
resolves to a *function*. Nothing calls `M.call('toggle_inlay_hint')`, so the
`enable`/`is_enabled` scope mismatch is invisible to the suite — the same shape
as Phase 4's F5. One case (`start_fake` with `inlayHintProvider`, call the
action, assert `is_enabled{bufnr=0}` flipped) covers it.

### P2 — a `.vscode/settings.json` reload throws away the ltex dictionaries

Two `LspAttach` handlers write `client.settings`, in this order:

1. `ucw.lsp.attach` (registered eagerly in `ucw.boot`) → `ucw.lsp.vscode.attach`,
   which snapshots `st.base = deepcopy(client.settings)` and pushes
   `base + .vscode/settings.json`;
2. `ucw.lsp.ltex` (registered from nvim-lspconfig's `config`, therefore later)
   → `ltex_dict.reload`, which reads `<root>/.vscode/ltex.*.txt` into
   `client.settings` and pushes that.

Every later reload of the settings file recomputes `merged = deepcopy(st.base)
+ files` (`vscode.lua:81-95`). `st.base` predates step 2, so everything step 2
added is discarded.

**Measured**, mini.test integration probe with an in-process fake `ltex_plus`
client (the `cmd`-as-function trick from `tests/test_lsp.lua`), root containing
both `.vscode/ltex.dictionary.en-US.txt` (`orloj`) and `.vscode/settings.json`:

```
at attach            settings.ltex = { dictionary = { ["en-US"] = { "orloj" } },
                                       language = "en-US" }
settings.json edited settings.ltex = { language = "de-DE" }
```

— and that second value is what gets pushed in
`workspace/didChangeConfiguration`. Every word ever added to the vault's
dictionary comes back as a spelling error until the server is restarted or
another word is added.

Not a contrived pairing: this phase deliberately put the per-project dictionary
in `<root>/.vscode/` (§5, "so a project's `.vscode/` directory works in both
editors"), which is the same directory as `settings.json`. A vault or a paper
that has one usually has the other.

**Not pre-existing.** The old implementation merged over
`config.static_settings or config.settings` — i.e. over whatever was current —
so it compounded rather than reset. The snapshot is new in Phase 3, and §5
justifies it ("so reloads merge over the static base rather than compounding")
without noticing that `client.settings` has a second author inside this same
codebase.

**Fix** (no new framework): have the reload announce itself, and let the other
contributor re-apply.

```lua
-- vscode.lua, after client:notify(...)
vim.api.nvim_exec_autocmds('User', {
  pattern = 'UcwLspSettingsReloaded',
  data = { client_id = client.id },
})

-- ltex_dict.lua: same callback it already uses for LspAttach
```

That keeps the "no private API" rule the phase is built on — it is a plain
autocmd, the way `attach.lua` argues plugins should hook in — and costs one
event.

### P3 — `g[` / `g]` have been dead since Phase 1

```lua
-- lua/ucw/plugins/which-key.lua:67-70
wk.add {
  { "g[", desc = "<cmd>lua require('ucw.keys.actions').diag_prev()<cr>" },
  { "g]", desc = "<cmd>lua require('ucw.keys.actions').diag_next()<cr>" },
}
```

The right-hand side is in `desc`, and there is no `[2]`, so which-key registers
a *description* for a key that has no mapping.

**Measured, real TUI, LSP attached:** `maparg('g[', 'n', false, true)` →
`vim.empty_dict()`. Same for `g]`. Neither key does anything; the buffer-local
keymap list contains `[` and `]` (from other plugins) but no `g[`/`g]`.

Introduced by `37c952a` (Phase 1's which-key v2 → v3 conversion). The v2 form
was a real mapping:

```lua
['['] = { [[<cmd>lua require('ucw.keys.actions').diag_prev()<cr>]], "Go to previous diagnostic" },
```

Reported here rather than deferred to Phase 9 because it is *exactly* the
failure mode this phase names as its own motivation —
`actions.lua:14-19`: *"a keymap whose rhs is `nil` simply does nothing, which
which-key happily accepts as a group, so the breakage stays invisible until the
key is pressed"* — sitting three lines below the block this phase rewrote. The
mechanism Phase 3 built to prevent it (`ucw.lsp.actions` + the resolvability
test) does not reach these two, because diagnostics are core rather than
`vim.lsp.*`.

**Fix**: give them a real rhs and a real description, and consider widening the
actions table to cover the core-diagnostic entry points (`diag_prev`,
`diag_next`, and `<leader>lp`'s toggle, which is also hand-written today) so
one test covers all of them.

### P4 — rustaceanvim's Mason dependency is undeclared and currently accidental

`lspconfig.lua` declares `dependencies = { 'williamboman/mason.nvim' }`, and
that is what puts `~/.local/share/nvim/mason/bin` on `PATH` before any of the
nine servers start. `rustaceanvim.lua` declares no dependency and loads on
`ft = { 'rust' }`; rust is deliberately absent from `servers.lua`, so opening a
Rust file loads **no** nvim-lspconfig and therefore nothing that calls
`mason.setup()`.

**Measured**, real TUI opened directly on `src/main.rs` of a Cargo project —
lazy.nvim's own record of why each plugin loaded:

```
mason.nvim   = { require = "mason-registry",
                 source  = ".../lazy/rustaceanvim/lua/rustaceanvim/config/internal.lua",
                 time    = 1.27 ms }
rustaceanvim = { ft = "rust", time = 34.2 ms }
```

So mason is pulled in by **rustaceanvim's own `pcall(require, 'mason-registry')`**
(`config/internal.lua:345`, probing for a codelldb DAP adapter), not by anything
in this config. rustaceanvim's `server.cmd` is a *function* resolved at client
start, which is after that, so it finds `mason/bin/rust-analyzer` and everything
works — today.

The fallback if it ever stops working is not "the system rust-analyzer". On
this machine `/usr/lib/rustup/bin/rust-analyzer` is on the interactive `PATH`
and is executable, but running it prints
`error: Unknown binary 'rust-analyzer' in official toolchain
'stable-x86_64-unknown-linux-gnu'`.

I simulated the loss by making `require('mason-registry')` throw before boot.
That is a blunt instrument — `mason/init.lua:2` requires the registry itself, so
it also prevents `mason.setup()` — so it does not isolate the probe. What it
does establish is the consequence of "no Mason `PATH` at Rust-buffer time":
**zero clients, nothing in `:messages`, nothing in `lsp.log`**. A silent loss of
all Rust LSP.

Worth flagging as a phase-introduced hole rather than an upstream quirk: before
this phase, `mason.nvim` and `rustaceanvim` were both gated on `User
UcwLspEnable` and came up together.

**Fix**: one line — `dependencies = { 'williamboman/mason.nvim' }` on the
rustaceanvim spec, mirroring `lspconfig.lua` — plus a test that asserts every
spec which starts a language server declares it.

### P5 — nothing cleans up on `LspDetach`

`attach.lua` adds buffer-local which-key mappings and `rustaceanvim.lua` adds
`<leader>a`; `vscode.lua` starts a 2-second-poll `FileWatcher` per workspace
folder and keeps `state[client.id]` forever unless the watcher happens to fire
again after the client stopped. Stop a client (`:lsp stop`, a crash, `:bd` on
the last buffer of a workspace) and `gd` still resolves to
`Telescope lsp_definitions` against no client, and the watcher keeps polling.

The old `setup_keymap` had the same shape, so this is **not** a regression, and
`vim.lsp.Client` ids are never reused so the table cannot collide. Recorded
because Phase 3 is the phase that made attach behaviour the only mechanism, and
because `LspDetach` is the natural companion the design never mentions.

### P6 — the phase's own verification is not written down

The convention this project adopted from Phase 3 onward (and executed in Phase
4) is: r1 proposes, r2 records decisions, r3 records **as-built and verification
results**. `phase3-lsp-redesign.md` r3 does the first half — it corrects the
performance figures and the upstream function-field survey — but §6 remains a
*plan* ("Verification, in the spirit of the previous phases") with no section
recording which of its eight items were run and what they produced. Phase 4's
document has §6a for exactly this, and this review was able to check Phase 4's
claims one by one because of it.

The results exist, in the commit message, which is the one place they cannot be
revised. Two of them are also now stale relative to the code:

* §4's `attach.lua` sketch still shows `if client:supports_method(...)` guards
  around inlay hints and codelens. The build deliberately dropped them, for a
  reason (`attach.lua:53-60`) that is better than the sketch's — it belongs in
  the document.
* §5 still says the inlay-hint toggle is "not bound to a key". It is
  (`<leader>lI`), which is how P1 became visible.

### P7 — the test suite is not deterministic

`just all` was **red on the first run of this review**:

```
FAIL in tests/test_comment.lua | gc | works as an operator over a visual selection:
  left = "<!-- local x = 1 -->", right = "-- local x = 1"
```

`just ci` immediately afterwards: 82/82, zero failures. Standalone runs of
`tests/test_comment.lua`: **2 of 6 red**, always the same case.

**Root cause, measured** — headless, no config:

```
children right after vim.treesitter.start(0):  {}
get_captures_at_pos(0, 5, 0):                  {}
children after parser:parse(true):             { "markdown_inline", "lua" }
```

`vim._comment.get_commentstring` walks `lang_tree:children()`
(`/usr/share/nvim/runtime/lua/vim/_comment.lua:54`). `vim.treesitter.start()`
only arms the highlighter; the injected `lua` tree does not exist until
something parses the whole buffer, which in the mini.test child happens on
redraw — i.e. in a race with the keys the test sends. All four injection cases
in that file are racing; the visual one loses most often.

**Fix** (event-based, no sleeps): force the parse in the fixture.

```lua
vim.treesitter.start(0)
vim.treesitter.get_parser(0):parse(true)   -- injections exist only after this
```

A probe with 8 copies of the failing case in each arm, run 4 times (32 cases per
arm): as-built 1 failure, forced-parse 0. Combined with the 2/6 standalone rate
above, and with the fact that the as-built arm reproduces at all while the
forced arm never has, that is enough to act on.

This is a Phase 4 file, but it is reported here because "the suite is green" is
the acceptance signal for *this* phase too, and it was not green on the first
try.

### P8 — three checkhealth warnings that will look like a regression later

`:checkhealth vim.lsp` on an attached Lua buffer reports `3 ⚠️`:

```
WARNING Unknown filetype 'c.doxygen'      (clangd, from servers.lua)
WARNING Unknown filetype 'cpp.doxygen'    (clangd)
WARNING Unknown filetype 'markdown.mdx'   (marksman)
```

All three come from upstream nvim-lspconfig's `filetypes`, which
`servers.lua` mirrors exactly because `tests/test_lsp.lua` requires exact
equality. They are inert (nothing ever sets those filetypes here, so the lazy
`ft` trigger entries are dead weight), but §6 listed `:checkhealth vim.lsp` as a
verification item and did not record them, so the next person to run it will
wonder.

---

## 2. Re-measured: what holds

Every §6 verification item, plus the load-bearing claims from §1-§4, re-run
against the real config.

| Claim | Re-measured |
|---|---|
| `:checkhealth vim.lsp` "Enabled Configurations" == `servers.lua`, no surprise auto-enables | exactly the nine: `basedpyright, clangd, jsonls, ltex_plus, lua_ls, marksman, ruff, taplo, texlab` |
| A Rust buffer attaches **one** client and renders inlay hints once | `clients = rust-analyzer` (one), screen shows `let v: String = String::from("x")` — one hint — plus the `▶︎ Run` codelens |
| `<leader>a` survives the duplicate-client fix (the `rust-analyzer` vs `rust_analyzer` filter) | buffer-local on the Rust buffer |
| Bare-`g` keymaps are ported verbatim | `g0 gW ge gD gd gt gH gr <C-K> <M-CR> <M-R>` all buffer-local; rhs matches `ucw.lsp.actions` |
| `after/lsp/` merges over nvim-lspconfig, function fields survive | `just ci` green; checkhealth shows lua_ls with upstream `cmd` + our `settings` + lazydev's `codeLens`/`hint` |
| `.vscode/settings.json` **initial load** (the half that never worked) | `typeCheckingMode = "off"` from the file is in `client.settings` at attach; 0 diagnostics on a deliberately wrong return type |
| `.vscode/settings.json` **live reload** | rewriting it to `"strict"` → `client.settings…typeCheckingMode = "strict"` and diagnostics 0 → 1, no restart |
| basedpyright's `didChangeWatchedFiles.dynamicRegistration` is a real change, not a restatement | `dynReg=true` and the client really registers `workspace/didChangeWatchedFiles`; `ruff` alongside it has `dynReg=false` and no registrations |
| marksman/ltex root detection in an Obsidian-shaped vault (`.obsidian`, no `.git`) | both attach with `root = /tmp/ucw-audit/vault`, 2 diagnostics from ltex |
| "Actually edit a file in each language" (§6 step 6) | lua → `lua_ls`; python → `basedpyright` + `ruff`; toml → `taplo`; c++ → `clangd` (+ `clangd_extensions` loaded); markdown → `marksman` + `ltex_plus`; tex → `texlab` + `ltex_plus`; json → `jsonls`, reports `Trailing comma`; rust → `rust-analyzer` |
| jsonls' documented runtime `node` requirement | reproduced: with `node` off `PATH` the client silently never attaches — nothing in `:messages`, nothing in `lsp.log`. With mise's node on `PATH`, it attaches and diagnoses. The warning in `servers.lua` is accurate and worth keeping |
| `ft` activation, at startup | starting on `main.rs`/`init.lua` attaches without any manual step |
| `ft` activation, mid-session | with no file: `nvim-lspconfig` not loaded, `mason`+`mason-lspconfig` loaded at VeryLazy; `:edit servers.lua` → lspconfig loads, `lua_ls` attaches, `gd` buffer-local |
| Context gating (`cond = is_full_ui`) | firenvim-shaped boot: `nvim-lspconfig`, `mason.nvim`, `mason-lspconfig.nvim`, `rustaceanvim`, `clangd_extensions.nvim`, `lsp-progress.nvim`, `lazydev.nvim` are all **absent from `lazy.core.config.plugins`**; 0 clients; the one `ucw.lsp.attach` autocmd remains, as documented |
| lsp-progress on `LspAttach` | loaded once a client exists |
| texlab forward search | `settings.texlab.forwardSearch.executable = "zathura"`, args carry this instance's `v:servername` |
| "Startup does not change at all" | headless `--startuptime`: 70.9 (cold) / 54.4 / 51.8 / 49.8 / 49.7 ms — in line with the Phase 4 numbers, i.e. no LSP cost at startup |
| "Quitting is not blocked by LSP" | a whole headless session that opens a file, waits for a client and quits: rust 159 ms, lua 118 ms end-to-end, process included |
| `just ci` | 82/82, 0 failures (on a run where P7 does not fire) |
| Hook layer is gone | no `ucw.lsp.hooks`, no `ucw.lsp.lang.*`, `package.loaded['lspconfig']` nil after the LSP stack is up |

Two observations that are correct-but-deferred rather than findings:

* The buffer-local `gr` shadows Neovim 0.11's native `gr` family (`grn`, `gra`,
  `grr`, `gri`, `grt` are all still mapped globally, so each now costs a
  `timeoutlen` — 500 ms here — of ambiguity). §5 explicitly hands binding
  *content* to Phase 9, so this is a note, not a defect.
* `.vscode/settings.json` is pushed to **every** client in the workspace, so
  `ruff` receives `basedpyright.*` keys (measured). Servers ignore foreign
  sections and the old implementation did the same; harmless, but it means the
  reload notification fires once per client per edit.

---

## 3. Recommended actions before accepting

1. **P1** — scope `toggle_inlay_hint` to the buffer, decide whether attach may
   override an explicit "off", and add the test that calls the action. Live
   defect on a key that ships bound.
2. **P2** — make `ucw.lsp.vscode`'s reload announce itself and have
   `ltex_dict` re-apply. Live defect, silent, and in the exact directory layout
   this phase chose.
3. **P3** — give `g[`/`g]` a real rhs. Two lines; and widen the actions table
   (or the test) so core-diagnostic entry points are covered the way `vim.lsp.*`
   ones now are.
4. **P4** — declare `dependencies = { 'williamboman/mason.nvim' }` on the
   rustaceanvim spec, with a test.
5. **P7** — force the injection parse in `tests/test_comment.lua`'s fixture, so
   "the suite is green" means something. Verify in reverse, per the standing
   rule: with the forced parse removed, the case must go back to failing
   intermittently.
6. **P6** — raise `phase3-lsp-redesign.md` to revision 4: add a §6a recording
   the verification results (the commit message's contents plus §2 above),
   correct §4's sketch to the built `attach.lua`, correct §5's "does not bind a
   key to it", and record P8 next to the checkhealth item.
7. **P5** — decide: either add an `LspDetach` handler (unmap, stop watchers,
   drop state) or write down that the leak is accepted.

None of this touches the phase's design decisions. The four that carry the most
weight — delete `hooks.lua` with nothing replacing it; `servers.lua` as the
single registration point; `ft`-triggered activation split hot/cold;
rustaceanvim keeps rust-analyzer and everything else rides `LspAttach` — all
re-measured sound, and the two headline bugs the phase set out to fix (the
duplicate rust client, the `.vscode` initial load) are genuinely fixed. The
findings are all in the seams: two mechanisms that both write `client.settings`,
two that both own the inlay-hint flag, and one spec whose dependency was never
written down.

---

## 4. Reproducing this review

```sh
just ci                                        # 82/82 - but run it twice, see P7

# P1
scripts/tui-drive.sh start lua/ucw/lsp/init.lua
scripts/tui-drive.sh lua 'return tostring(vim.lsp.inlay_hint.is_enabled({bufnr=0}))
                            .. " " .. tostring(vim.lsp.inlay_hint.is_enabled())'
scripts/tui-drive.sh send ' lI'                # leader is space
#   -> buf=true global=true   (first press turns nothing off)
scripts/tui-drive.sh cmd 'edit <another .lua>' # -> buf=true again

# P2: mini.test probe, fake ltex_plus client, root with both
#   .vscode/ltex.dictionary.en-US.txt and .vscode/settings.json
#   (pattern: tests/test_lsp.lua's new_fake_server + T['ltex'])
#   assert settings.ltex before and after rewriting settings.json

# P3
scripts/tui-drive.sh lua 'return vim.inspect(vim.fn.maparg("g[", "n", false, true))'
#   -> vim.empty_dict()

# P4
scripts/tui-drive.sh start <cargo project>/src/main.rs
scripts/tui-drive.sh lua 'return vim.inspect(require("lazy.core.config").plugins["mason.nvim"]._.loaded)'
#   -> source = .../rustaceanvim/lua/rustaceanvim/config/internal.lua
/usr/lib/rustup/bin/rust-analyzer --version    # the fallback, and it errors

# P7
nvim --headless --clean -u ./tests/aux/driver_init.lua \
  -c "lua MiniTest.run_file('tests/test_comment.lua')" -c 'qa!'   # repeat ~6x
nvim --headless --clean -u NONE -c 'lua
  vim.cmd.edit("<a .md file with a lua fence>")
  vim.treesitter.start(0)
  print(vim.inspect(vim.tbl_keys(vim.treesitter.get_parser(0):children())))  -- {}
  vim.treesitter.get_parser(0):parse(true)
  print(vim.inspect(vim.tbl_keys(vim.treesitter.get_parser(0):children())))  -- lua
' -c 'qa!'
```

The firenvim-shaped boot uses the wrapper from
`docs/design/phase4-acceptance-review.md` §4 (tui-drive's `start` does not
preserve quoting in `--cmd`). The jsonls check needs `node` on `PATH`, which a
non-interactive shell does not get from mise — use a wrapper that prepends
`~/.local/share/mise/installs/node/25/bin`.
