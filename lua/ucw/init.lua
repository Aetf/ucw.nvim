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

local target = 'target.tui'
if utils.is_gui() then
  target = 'target.gui'
elseif vim.g.started_by_firenvim then
  target = 'target.firenvim'
elseif vim.g.neovide then
  target = 'target.neovide'
end

require('nvimd').boot(
  {
    units_modules ={
      'ucw.units.thirdparty',
      'ucw.units.user',
    }
  },
  target
)
