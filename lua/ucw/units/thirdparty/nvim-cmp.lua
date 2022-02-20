local M = {}

M.url = 'hrsh7th/nvim-cmp'
M.description = 'Completion engine'

M.wants = {
  'cmp-buffer',
  'cmp-path',
  'cmp-cmdline',
  'cmp-nvim-lua',
  'cmp-under-comparator',
  'lspkind',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.completion'
  }
}

-- configs
M.config = require('ucw.cmp').config

return M
