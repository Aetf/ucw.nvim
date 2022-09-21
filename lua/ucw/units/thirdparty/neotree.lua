local M = {}

M.url = 'nvim-neo-tree/neo-tree.nvim'
M.description = 'Neovim plugin to manage the file system and other tree like structures.'
M.install_opts = {
  branch = 'v2.x'
}

M.requires = {
  "plenary",
  "nui",
  -- FUTURE: remove direct dependency on which-key, call vim keymap define directly
  'which-key',
}
M.wants = {
  "nvim-web-devicons",
  'dressing', -- for rename input
}
M.after = {
  "plenary",
  "nvim-web-devicons",
  "nui",
  'which-key',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

M.setup = require('ucw.neotree').setup
M.config = require('ucw.neotree').config

return M
