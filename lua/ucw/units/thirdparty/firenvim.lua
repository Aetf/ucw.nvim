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
      ['teams.microsoft.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['mail\\.google\\.com'] = {
        selector = 'div[role="textbox"][aria-label="Message Body"]',
        priority = 1,
      },
      ['docs\\.google\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['slides\\.google\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['sheets\\.google\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      ['overleaf\\.com'] = {
        takeover = 'never',
        priority = 1,
      },
      -- TODO: skip inline for jupyterlab
      -- :not([data-type=="inline"])
      ['.*'] = {
        cmdline = 'firenvim',
        takeover = 'always',
        priority = 0,
      },
    },
  }
  -- set filetype for specific textareas
  au.BufEnter = {
    'github.com_*.txt',
    function() vim.opt_local.filetype = 'markdown' end
  }

  -- default to soft wrap and no hard wrap when editing on websites
  vim.opt.wrap = false
  vim.opt.textwidth = 0

  -- extra keybindings
  map('n', '<esc><esc>', [[<cmd>call firenvim#focus_page()<cr>]])
  map('n', '<c-z>', [[<cmd>call firenvim#hide_frame()<cr>]])
  map('n', '<cr><cr>', [[<cmd>lua vim.opt.lines = math.max(vim.opt.lines:get(), 25) vim.opt.laststatus=2<cr>]])
end

return M
