return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v2.x',
  lazy = false,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'echasnovski/mini.nvim',
  },
  init = require('ucw.neotree').setup,
  config = require('ucw.neotree').config,
}
