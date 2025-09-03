local M = {}

M.url = 'williamboman/mason-lspconfig.nvim'
M.description = 'Extension to mason.nvim that makes it easier to use lspconfig with mason.nvim'

M.requisite = {
  'mason',
  'lspconfig',
}
M.after = {
  'mason',
  'lspconfig',
}

M.activation = {
  wanted_by = {
    'target.lsp',
  }
}

function M.config()
  require('mason-lspconfig').setup {
    -- vim.lsp.enable all installed servers
    automatic_enable = true,
  }
end

return M
