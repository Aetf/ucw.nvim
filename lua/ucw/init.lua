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

require('nvimd').boot(
  {
    units_modules ={
      'ucw.units.thirdparty',
      'ucw.units.user',
    }
  },
  utils.is_gui() and 'target.gui' or 'target.tui'
)
