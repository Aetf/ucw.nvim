local M = {}

M.url = 'JoosepAlviste/nvim-ts-context-commentstring'
M.description = 'Set commentstring based on ts'

M.after = {
  'treesitter',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'treesitter'
  }
}

return M
