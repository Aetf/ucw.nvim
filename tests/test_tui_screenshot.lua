-- Example TUI screenshot test.
--
-- Demonstrates how to observe what the config *actually renders* from within the
-- test suite, using mini.test's child Neovim. `child.get_screenshot()` returns
-- the rendered screen grid (text + highlight attributes + cursor) as read via
-- screenstring()/screenattr(), so assertions can be made against the real TUI,
-- not just buffer contents or logs.
--
-- The child boots the full ucw.nvim config (integration test), so lazy units
-- activate exactly as they do interactively. Default child screen is 24x80.
--
-- See docs/tui-observation.md for the full workflow (incl. the tmux driver and
-- nvim__screenshot).

local H = require('helpers')
local new_set = MiniTest.new_set

local T, child = H.new_integration_test()

-- `expect.equality(screen:find(...) ~= nil, true)` reports `false ~= true` and
-- nothing else, which is useless for the one failure mode these cases have:
-- something was drawn over the text. Both were written that way and the first
-- one went red exactly once, on a CI runner, with no way to tell what covered
-- it. So the screen goes in the failure message.
local function expect_on_screen(screen, pattern, what)
  if screen:find(pattern) ~= nil then
    return
  end
  error(('%s not found on the rendered screen.\nScreen was:\n%s'):format(what, screen))
end

T['screenshot'] = new_set()

-- Reads the rendered grid and asserts on visible text. Robust across terminals
-- because it only checks that expected text is present, not exact colors.
T['screenshot']['sees buffer text on screen'] = function()
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'hello from ucw.nvim', 'second line' })

  local shot = child.get_screenshot() -- implies :redraw
  local screen = tostring(shot) -- whole screen as a multi-line string

  expect_on_screen(screen, 'hello from ucw%.nvim', 'buffer text')
  -- `shot.text` / `shot.attr` are 2d arrays if you need per-cell checks, e.g.
  -- the first text row: table.concat(shot.text[1])
end

-- Opens a floating window and confirms its rendered content shows up in the
-- screenshot grid. Config-independent, so it stays green regardless of which
-- plugins the test target pulls in; it demonstrates reading a float off-screen.
T['screenshot']['sees floating window content'] = function()
  child.lua([[
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, true, { 'floating hello' })
        vim.api.nvim_open_win(buf, false, {
            relative = 'editor', row = 2, col = 4, width = 20, height = 1,
            border = 'rounded', style = 'minimal',
        })
    ]])

  local screen = tostring(child.get_screenshot())
  expect_on_screen(screen, 'floating hello', 'floating window content')

  -- Pixel-for-pixel reference screenshots are also supported, but are sensitive
  -- to colorscheme / plugin versions, so they are not used here:
  --   MiniTest.expect.reference_screenshot(child.get_screenshot())
  -- On first run this writes tests/screenshots/<case-path>; later runs diff it.
  --
  -- To screenshot a lazily-loaded plugin's UI (neo-tree, which-key, …), first
  -- trigger its lazy.nvim load in the child, e.g.:
  --   child.lua('Snacks.picker.files()')
end

return T
