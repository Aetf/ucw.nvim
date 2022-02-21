local M = {}

M.url = 'williamboman/nvim-lsp-installer'
M.description = 'Automatically manage lsp server installation and setup'

M.requires = {
  'lspconfig',
}
M.after = {
  'lspconfig',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('ucw.lsp').setup()
end

return M
