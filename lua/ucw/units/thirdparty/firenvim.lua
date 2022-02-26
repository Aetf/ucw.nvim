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

local L = vim.loop
local au = require('au')
local map = require('ucw.utils').map

function M.config()
  vim.g.firenvim_config = {
    globalSettings = {
      ['<C-n>'] = 'default',
      ['<C-t>'] = 'default',
      ignoreKeys = {
        all = {'<C-TAB>', '<C-S-TAB>',},
      }
    },
    localSettings = {
      ['mail\\.google\\.com'] = {
        selector = 'div[role="textbox"][aria-label="Message Body"]',
        priority = 1,
      },
      ['docs\\.google\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['overleaf\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['.*'] = {
        cmdline = 'neovim',
        takeover = 'always',
        priority = 0,
      },
    },
  }
  -- set filetype for specific textareas
  au.BufEnter = {
    'github.com_*.txt',
    function() vim.opt.filetype = 'markdown' end
  }

  -- sync text with debounce
  local timer = L.new_timer()
  local function write_debounce()
    timer:stop()
    timer:start(1000, 0, vim.schedule_wrap(function() vim.cmd('write') end))
  end
  au.group('FirenvimSync', {
    { 'TextChanged', '*', write_debounce, nested = true },
    { 'TextChangedI', '*', write_debounce, nested = true },
  })

  -- extra keybindings
  map('n', '<esc><esc>', [[<cmd>call firenvim#focus_page()<cr>]])
  map('n', '<c-z>', [[<cmd>call firenvim#hide_frame()<cr>]])
  map('n', '<cr><cr>', [[<cmd>lua vim.opt.lines = math.max(vim.opt.lines.get(), 25)<cr>]])
end

return M
