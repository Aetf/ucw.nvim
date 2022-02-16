local M = {}

M.url = 'p00f/nvim-ts-rainbow'
M.description = 'Rainbow!'

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
