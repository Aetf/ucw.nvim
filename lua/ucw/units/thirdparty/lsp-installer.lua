local M = {}

M.url = 'williamboman/nvim-lsp-installer'
M.description = 'Automatically manage lsp server installation and setup'

M.requires = {
  'lspconfig',
}
M.after = {
  'lspconfig',
}

return M
