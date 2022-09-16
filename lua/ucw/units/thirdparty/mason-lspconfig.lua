local M = {}

M.url = 'williamboman/mason-lspconfig.nvim'
M.description = 'Extension to mason.nvim that makes it easier to use lspconfig with mason.nvim'

M.requisite = {
  'mason',
  'lspconfig',
}
M.after = {
  'mason',
  -- the doc says to *setup* mason-lspconfig *before* lspconfig, but the fact is,
  -- lspconfig still has to be *loaded* before mason-lspconfig because
  -- mason-lspconfig imports 'lspconfig' in its setup.
  'lspconfig',
}

M.activation = {
  wanted_by = {
    'target.lsp',
  }
}

function M.config()
  require('mason-lspconfig').setup()
end

return M
