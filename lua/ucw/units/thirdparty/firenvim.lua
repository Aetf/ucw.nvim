---@type nvimd.Unit
local M = {}

M.url = 'glacambre/firenvim'
M.description = 'Use nvim in browser'

M.run = function()
  vim.fn['firenvim#install'](0)
end

M.activation = {
  wanted_by = {
    'target.firenvim',
  }
}

local map = require('ucw.utils').map

function M.config()
  vim.g.firenvim_config = {
    globalSettings = {
    },
    localSettings = {
      ['.*'] = {
        takeover = 'always',
      },
    },
  }

  -- extra keybindings
  map('n', '<esc><esc>', [[<cmd>call firenvim#focus_page()<cr>]])
  map('n', '<c-z>', [[<cmd>call firenvim#hide_frame()<cr>]])
end

return M
