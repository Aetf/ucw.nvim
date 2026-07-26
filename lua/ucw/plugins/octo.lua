return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    require('octo').setup {}
    local wk = require('which-key')
    wk.register {
      ['<leader>g'] = {
        o = {
          name = "+octo (GitHub)",
          o = { [[<cmd>Octo actions<cr>]], "Pick an action" },
          i = { [[<cmd>Octo issue search<cr>]], "Search issues" },
          p = { [[<cmd>Octo pr search<cr>]], "Search issues" },
        }
      }
    }
  end,
}
