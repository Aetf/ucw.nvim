local M = {}

M.url = 'nvim-telescope/telescope-fzf-native.nvim'
M.description = 'Native sorting algorithm for telescope'
M.run = 'make'

M.after = {
  'telescope',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'telescope'
  }
}

function M.config()
  require('telescope').load_extension 'fzf'
end

return M
