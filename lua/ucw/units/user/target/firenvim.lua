local M = {}

M.description = 'Settings related to running in firenvim'

M.wants = {
  'target.basic',
}

local au = require('au')

function M.config()
  -- classic-light
  -- equilibrium-gray-light
  -- humanoid-light
  -- one-light
  -- base16-atelier-forest-light
  vim.cmd [[colorscheme base16-one-light]]
  -- no status bar
  vim.opt.laststatus = 0
  au.UIEnter = function()
    vim.opt.guifont = 'Hack Nerd Font Mono:h18'
    vim.defer_fn(function()
      -- enforce a minimum line height
      -- this has to be done a while after the set guifont, to avoid race conditions
      -- see https://github.com/glacambre/firenvim/issues/800
      -- vim.opt.lines = math.max(vim.opt.lines:get(), 20)
    end, 1000)
  end
end

return M
