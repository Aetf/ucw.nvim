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
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T, child = H.new_integration_test()

T['screenshot'] = new_set()

-- Reads the rendered grid and asserts on visible text. Robust across terminals
-- because it only checks that expected text is present, not exact colors.
T['screenshot']['sees buffer text on screen'] = function()
    child.api.nvim_buf_set_lines(0, 0, -1, true, { 'hello from ucw.nvim', 'second line' })

    local shot = child.get_screenshot() -- implies :redraw
    local screen = tostring(shot) -- whole screen as a multi-line string

    expect.equality(screen:find('hello from ucw%.nvim') ~= nil, true)
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
    expect.equality(screen:find('floating hello') ~= nil, true)

    -- Pixel-for-pixel reference screenshots are also supported, but are sensitive
    -- to colorscheme / plugin versions, so they are not used here:
    --   MiniTest.expect.reference_screenshot(child.get_screenshot())
    -- On first run this writes tests/screenshots/<case-path>; later runs diff it.
    --
    -- To screenshot a lazily-loaded plugin's UI (telescope, which-key, …), first
    -- activate it in the child, e.g.:
    --   child.lua([[nvimctl:start('target.tui')]]) ; child.cmd('Telescope find_files')
end

return T
