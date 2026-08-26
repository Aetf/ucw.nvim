# Observing the rendered TUI

When testing config changes, logs alone are not enough — a plugin can log "ok" and
still render nothing, draw a broken statusline, or leave a blocking prompt. This doc
describes how to observe what Neovim *actually draws* — screen text, colors, floating
windows, the cursor — both interactively and in tests.

All commands below were verified on this machine: nvim 0.12.3, tmux 3.7b, mini.test
via `just deps`.

There are three tiers, most-to-least recommended by use case.

---

## Tier A — reproducible screenshots in tests (mini.test child)

The test harness already spawns a child Neovim with a real UI attached, and
`child.get_screenshot()` returns the rendered grid. This is the canonical way to lock
UI behavior into the suite.

```lua
local shot = child.get_screenshot()   -- implies :redraw
local screen = tostring(shot)         -- whole screen as one string
screen:find('Find Files')             -- assert visible text
-- shot.text / shot.attr are 2d arrays (per-cell char / highlight attr)
-- shot.text[1] is the first row; table.concat(shot.text[1]) is that row's text
```

Default child screen is **24×80**. `get_screenshot()` reads the live grid via
`screenstring()` / `screenattr()`.

Pixel-for-pixel assertions are available too:

```lua
MiniTest.expect.reference_screenshot(child.get_screenshot())
-- first run writes tests/screenshots/<case-path>; later runs diff against it
```

Reference screenshots are sensitive to colorscheme / plugin versions, so prefer
text `:find` assertions unless you specifically want to pin exact rendering.

Working example: **`tests/test_tui_screenshot.lua`** — one case checks buffer text on
screen, another screenshots a floating window. Run just that file:

```sh
nvim --headless --clean -u tests/aux/driver_init.lua \
  -c "lua MiniTest.run_file('tests/test_tui_screenshot.lua')" -c "qa!"
```

The integration harness boots the whole config (`require('ucw').boot()`), so start
plugins are already up. To screenshot a **lazily-loaded** plugin's UI, fire its lazy
trigger — or load it explicitly — in the child first:

```lua
child.lua([[require('lazy').load({ plugins = { 'neo-tree.nvim' } })]])
child.lua('Snacks.picker.files()')
-- then wait on the condition, not on a duration: poll until the float exists
child.lua([[vim.wait(2000, function() return #vim.api.nvim_list_wins() > 1 end)]])
```

---

## Tier B — ad-hoc live inspection (tmux driver)

For interactive/agent debugging of the **real** config, `scripts/tui-drive.sh` runs
nvim in a detached tmux session (real terminal rendering) plus an nvim `--listen`
control socket (reliable scripted input + `:messages` + screenshots). Because the
session is detached, an agent can drive it and read the screen back without a TTY.

```sh
scripts/tui-drive.sh start                 # boot the real ~/.config/nvim config
scripts/tui-drive.sh capture               # dump the current screen (plain text)
scripts/tui-drive.sh capture-color         # same, with truecolor SGR escapes
scripts/tui-drive.sh send ':lua Snacks.picker.files()<CR>'  # Neovim key notation
scripts/tui-drive.sh cmd 'edit README.md'  # run an ex command from normal mode
scripts/tui-drive.sh expr 'v:version'      # eval a Vimscript expression
scripts/tui-drive.sh lua 'return tostring(vim.version())'
scripts/tui-drive.sh messages              # :messages WITHOUT blocking on hit-enter
scripts/tui-drive.sh screenshot /tmp/s.txt # nvim__screenshot (Tier C) to a file
scripts/tui-drive.sh stop                  # kill session + remove socket
```

Notes / gotchas:

- **`send` vs `keys`**: `send` injects via the control socket in Neovim key notation
  (`<CR>`, `<Esc>`, `<C-w>`). `keys` uses raw tmux key events (`C-c`) for things the
  RPC channel cannot inject.
- **Settle before capturing.** `send`/`cmd` are asynchronous and lazy units take a
  moment to `packadd` + `config`. If a `capture` shows an intermediate state (e.g. an
  empty noice cmdline box), capture again a beat later. In scripts, poll for expected
  text rather than capturing once.
- **`messages` never blocks.** It routes through the socket, so it reads the message
  history even while a hit-enter prompt is on screen — which is exactly how the bug
  below was diagnosed.
- **Size** is fixed via `UCW_TUI_COLS`/`UCW_TUI_ROWS` (default 200×50) so wrapping is
  predictable. Session name / socket path are overridable via `UCW_TUI_SESSION` /
  `UCW_TUI_SOCK`.
- **Isolation**: `start` loads the real config by default. To sandbox, pass nvim args,
  e.g. `start --clean -u tests/aux/driver_init.lua`, or set a throwaway
  `NVIM_APPNAME` / `XDG_DATA_HOME` in the environment before `start`.
- **`stop` overwrites your saved session for the cwd.** The real config means real
  auto-session: killing the tmux session runs the `VimLeavePre` autosave, so whatever
  scratch layout the probe left behind becomes the session for that directory. Noticed
  after driving the Phase 5 acceptance review — `~/.local/share/nvim/sessions/` had a
  fresh entry for `~/.config/nvim`. Use a throwaway `XDG_DATA_HOME` (above) if the
  saved session for the directory you are testing in matters. The **test suite is not
  affected**: the mini.test child already gets its own `XDG_DATA_HOME` (verified — the
  session file's mtime does not move across a `just` run).

---

## Tier C — `nvim__screenshot` (reference / background)

`vim.api.nvim__screenshot(path)` dumps the current grid to a file when a UI is
attached. It underlies mini.test's `get_screenshot()`. On nvim 0.12 the output is a
**truecolor ANSI rendering** (first line is `rows,columns`, then SGR-escaped screen
rows) — useful if you want the colors, less so for diffing. It is an internal/unstable
API (double-underscore); prefer Tier A/B. The driver's `screenshot` verb wraps it:

```sh
scripts/tui-drive.sh screenshot /tmp/ucw-shot.txt   # ~29 KB truecolor dump
```

---

## Worked example: a real startup bug found with these tools

Running the config through the tmux driver caught a real issue immediately. (Kept for
the method, not the specifics — see the note at the end of this section.)

```sh
scripts/tui-drive.sh start
scripts/tui-drive.sh capture     # showed a bordered "Press any key to continue" popup
scripts/tui-drive.sh messages    # revealed the actual error:
```

```
Error in /home/aetf/.config/nvim/init.lua:
tree-sitter CLI not found: `tree-sitter` is not executable!
tree-sitter CLI is needed because `latex` is marked that it needs to be generated
from the grammar definitions to be compatible with nvim!
```

Diagnosis: `latex` was in `ensure_installed`, but nvim-treesitter needs the
`tree-sitter` CLI to generate that parser and no CLI was resolvable. The error fired
during `init.lua` on **every** boot, producing a hit-enter prompt (which noice reskins
as "Press any key to continue").

Notably, the engine's own log and `stderr` were **empty** — this was only visible by
looking at the screen / `:messages`, which is the whole point of TUI observation, and
the reason this example is kept.

> **This example is history, and every particular in it has since changed.** It
> predates Phase 1, so the file it named (`lua/ucw/units/thirdparty/treesitter.lua`)
> and the log it named (`nvimd.log`) were both deleted with the nvimd engine;
> `ensure_installed` lives in `lua/ucw/plugins/treesitter.lua` now and no longer
> contains `latex`; the boot-time install is gated on a full-UI session
> (`design/phase6.5-acceptance-review.md` R1) and warns once instead of erroring; and
> the "no CLI anywhere" premise is itself wrong — this machine has had `tree-sitter`
> via mise since 2026-08-04, which nothing in the editor could see
> (`design/phase6.5-binary-deps.md` §3.3). The **method** is what this section
> teaches; do not read the specifics as current.
