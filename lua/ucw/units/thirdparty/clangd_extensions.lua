local M = {}

M.url = 'p00f/clangd_extensions.nvim'
M.description = 'Extra functionality for clangd'

M.after = {
  'mason-lspconfig',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('clangd_extensions').setup{}
end

return M
