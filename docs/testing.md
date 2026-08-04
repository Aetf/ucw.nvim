# Testing

The test harness is [mini.test](https://github.com/echasnovski/mini.nvim). This
expands the short note in `../tests/README.md`.

## Running

```sh
just deps        # clone/update mini.nvim into deps/mini.nvim (gitignored)
just unit        # tag: unit
just int         # tag: integration (boots the full config; installs plugins)
just all         # both
just ci          # both, do not stop on first error
```

Under the hood every recipe runs headless nvim with the driver:

```sh
nvim --headless --clean \
  --cmd 'let g:TestTags = "<tags>"' \
  --cmd 'let g:TestExecuteStopOnError = v:<true|false>' \
  -u ./tests/aux/driver_init.lua \
  -S ./tests/aux/driver_run.lua
```

`g:TestTags` is a space-separated tag filter (`tests/aux/driver_run.lua` keeps only
cases matching **all** given tags). `just deps` is a dependency of `test`, so mini.nvim
is fetched automatically.

### Run a single file

`just` always runs the whole suite. To iterate on one file, call `run_file` directly:

```sh
nvim --headless --clean -u tests/aux/driver_init.lua \
  -c "lua MiniTest.run_file('tests/test_tui_screenshot.lua')" -c "qa!"
```

## Two-stage model

1. **Driver** — a headless nvim initialized by `tests/aux/driver_init.lua` with a clean
   runtime path (`--clean`). It only adds mini.test and `tests/aux` to the rtp, then
   runs each `tests/test_*.lua`.
2. **Child** — each test spawns a fresh child nvim per case
   (`MiniTest.new_child_neovim()`), driven over RPC. The child has a real UI attached,
   which is what makes screenshots possible (see `tui-observation.md`).

## Writing tests

Two helpers in `tests/aux/lua/helpers.lua`:

```lua
local H = require('helpers')

-- Unit: no nvimd. Only cwd + mini.test on rtp. Fast. Auto-tagged "unit".
local T, child = H.new_unit_test()

-- Integration: boots the whole ucw.nvim config. Auto-tagged "integration".
local T, child = H.new_integration_test()
```

- **Unit tests** are for pure modules — require the module in the child and assert on
  return values. Example: `tests/test_ipython_cell.lua` parametrizes cases and checks
  `M.cell(...)` output with `MiniTest.expect.equality`.
- **Integration tests** boot the full config in the child. The harness points
  `XDG_DATA_HOME` at a fresh temp dir per run, so the **plugin install path is
  exercised every time** (slower), and blocks on `lazy.manage.install()` so a test
  never races the installer. Everything is `lazy.nvim`-lazy in the child, so a
  test that needs a plugin loads it explicitly
  (`require('lazy').load({ plugins = { 'nvim-lspconfig' } })`). Example:
  `tests/test_boot.lua` is a smoke test that just boots without error.

### Common child patterns

```lua
child.api.nvim_buf_set_lines(0, 0, -1, true, { 'line' }) -- redirection tables → vim.*
child.lua([[ return 1 + 1 ]])         -- run Lua in the child, return a value
child.lua_get([[ M.foo(...) ]], {arg}) -- eval an expression with args
child.cmd('edit README.md')            -- ex command
child.type_keys('i', 'hello', '<Esc>') -- feed keys
child.get_screenshot()                 -- rendered grid (see tui-observation.md)
```

Beware **hanging**: a child blocks if it hits a `hit-enter` prompt or stays in
operator-pending mode. Most helpers guard against this; if you get a hang, exit to
normal mode (`child.ensure_normal_mode()`) and/or raise `cmdheight`.

## Adding tests

Drop a `tests/test_<name>.lua` returning a `MiniTest.new_set()` (the helpers return
one). It is picked up automatically and tagged unit/integration by the helper you use.
Tests under `tests/` use 4-space indent (match the sibling files).

## Rules earned the hard way

Each of these comes from a bug that shipped green, recorded in
`docs/design/phase*-acceptance-review.md`. They cost nothing to follow and each
one has already caught something.

- **Verify a regression test in reverse.** After fixing a bug, revert the fix and
  confirm *that* test — and ideally only that test — goes red. A test written
  from the same mental model as the fix passes either way otherwise; Phase 4's
  fold tests were green both with and without the bug they were meant to pin.
- **Test the seams, not just the modules.** Every Phase 3 finding was between two
  modules, never inside one: two owners of one flag, two authors of one settings
  table, one plugin depending on another's side effect. Per-module tests cannot
  see any of that by construction — assert the *combined* end state.
- **Never leave a test racing an async subsystem.** No sleeps and no retries:
  find the call that makes it synchronous. Notably, `vim.treesitter.start()` only
  arms the highlighter — injected language trees do not exist until something
  parses, so a test touching injections needs an explicit
  `vim.treesitter.get_parser(0):parse(true)`. Without it `tests/test_comment.lua`
  passed about two runs in three, which is worse than failing.
- **Run the suite twice before believing it.** A single green run does not
  distinguish "correct" from "lucky".
- **Green is not acceptance.** Two Phase 3 bugs and two Phase 4 bugs were found
  only by driving a real TUI (`docs/tui-observation.md`) while the whole suite
  was green. Assert on what is actually on screen or in `:messages`.
- **Capture the "before" before changing anything.** A regression only looks like
  one next to a baseline. Phase 5 dropped a session hook on the strength of an
  upstream option covering it, and the restored layout that came back with an
  extra window looked perfectly plausible on its own — the pre-change recording
  of the same save/restore cycle is the only reason it was caught.
- **An option's default is not a call site.** `close_unsupported_windows`
  defaults to `true`, which says nothing about *when* it runs — it is invoked
  from the autosave path only. Reading a config table is the same class of
  mistake as grepping for a function name; trace it to where it is called.
- **When a probe reports something startling, suspect the probe.** An RPC
  `nvim_exec_lua` runs in whatever buffer is current, and a picker that has just
  closed still is — which made a buffer-local keymap read like a broken global
  one. Check `maparg().buffer`, and use `bufname('%')`: `bufname(0)` asks for
  buffer number 0, which does not exist, and answers `''`.

## Gaps

- **No CI.** The `just ci` recipe exists but nothing runs it on push. A GitHub Actions
  workflow that runs `just ci` (with `tree-sitter` CLI available, see
  `tui-observation.md`) would be the natural next step.
