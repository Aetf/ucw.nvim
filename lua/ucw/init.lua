local utils = require('ucw.utils')

-- Disable unused plugin hosts given we have lua now
vim.g.loaded_python3_provider = 0
vim.g.loaded_python_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- The normal options and tweaks that doesn't rely on plugins
require('ucw.options')
require('ucw.keys')
require('ucw.extras')

-- Extra options for neovide
if vim.g.neovide then
  require('ucw.neovide')
end

local nvimd = require('nvimd')
local nvimctl = nvimd.setup {
  units_modules ={
    'ucw.units.thirdparty',
    'ucw.units.user',
  }
}

if utils.is_gui() then
  nvimctl:start 'target.tui'
else
  nvimctl:start 'target.gui'
end

-- Lazy loading plugin management, see comments in it for more details
-- require('ucw.plugins').setup()
