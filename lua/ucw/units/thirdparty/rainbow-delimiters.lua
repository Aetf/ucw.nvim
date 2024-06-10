local M = {}

M.url = 'https://gitlab.com/HiPhish/rainbow-delimiters.nvim'
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
