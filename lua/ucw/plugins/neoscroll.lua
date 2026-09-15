return {
  'karb94/neoscroll.nvim',
  lazy = false,
  config = function()
    local neoscroll = require('neoscroll')
    -- The plugin's own nine mappings, bound here so that each carries a
    -- `desc` (the plugin binds them bare); functions and durations are the
    -- plugin's defaults (`function_mappings` in neoscroll/init.lua).
    neoscroll.setup {
      stop_eof = false,
      mappings = {},
    }
    local modes = { 'n', 'v', 'x' }
    local smooth = {
      {
        '<C-u>',
        'Scroll half a page up',
        function()
          neoscroll.ctrl_u { duration = 250 }
        end,
      },
      {
        '<C-d>',
        'Scroll half a page down',
        function()
          neoscroll.ctrl_d { duration = 250 }
        end,
      },
      {
        '<C-b>',
        'Scroll a page up',
        function()
          neoscroll.ctrl_b { duration = 450 }
        end,
      },
      {
        '<C-f>',
        'Scroll a page down',
        function()
          neoscroll.ctrl_f { duration = 450 }
        end,
      },
      {
        '<C-y>',
        'Scroll the view up a little',
        function()
          neoscroll.scroll(-0.1, { move_cursor = false, duration = 100 })
        end,
      },
      {
        '<C-e>',
        'Scroll the view down a little',
        function()
          neoscroll.scroll(0.1, { move_cursor = false, duration = 100 })
        end,
      },
      {
        'zt',
        'Cursor line to the top',
        function()
          neoscroll.zt { half_win_duration = 250 }
        end,
      },
      {
        'zz',
        'Cursor line to the middle',
        function()
          neoscroll.zz { half_win_duration = 250 }
        end,
      },
      {
        'zb',
        'Cursor line to the bottom',
        function()
          neoscroll.zb { half_win_duration = 250 }
        end,
      },
    }
    for _, m in ipairs(smooth) do
      vim.keymap.set(modes, m[1], m[3], { desc = m[2] .. ' (smooth)' })
    end
  end,
}
