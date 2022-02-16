local M = {}

M.url = 'tpope/vim-sleuth'
M.description = 'Automatically detect shiftwidth of current file'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

return M
