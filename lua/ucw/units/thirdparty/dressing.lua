local M = {}

M.url = 'stevearc/dressing.nvim'
M.description = 'Use telescope for vim.ui'

M.requires = {
  'telescope',
}
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
  require('dressing').setup()
end

return M
