local M = {}

M.url = 'pwntester/octo.nvim'
M.description = 'Edit and review GitHub issues and pull requests from the comfort of your favorite editor'

M.requires = {
  'plenary',
}
M.wants = {
  'telescope',
  'mini-icons',
}

M.activation = {
  cmd = "Octo"
}

function M.config ()
  require('octo').setup {
  }
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
end

return M
