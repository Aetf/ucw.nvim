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
  exercised every time** (slower). The child starts the `mini-test` target
  (`nvimctl:start('mini-test')`), not the full TUI target — activate other
  targets/units explicitly if a test needs them. Example: `tests/test_boot.lua` is a
  smoke test that just boots without error.

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

## Gaps

- **No CI.** The `just ci` recipe exists but nothing runs it on push. A GitHub Actions
  workflow that runs `just ci` (with `tree-sitter` CLI available, see
  `tui-observation.md`) would be the natural next step.
