local M = {}

M.url = 'nvim-neo-tree/neo-tree.nvim'
M.description = 'Neovim plugin to manage the file system and other tree like structures.'
M.install_opts = {
  branch = 'v2.x'
}

M.requires = {
  "plenary",
  "nui",
}
M.wants = {
  "nvim-web-devicons",
}
M.after = {
  "plenary",
  "nvim-web-devicons",
  "nui",
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
