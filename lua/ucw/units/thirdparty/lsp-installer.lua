local M = {}

M.url = 'williamboman/nvim-lsp-installer'
M.description = 'Automatically manage lsp server installation and setup'

M.requires = {
  'lspconfig',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  local lsp_installer = require("nvim-lsp-installer")

  lsp_installer.on_server_ready(require('ucw.lsp').on_server_ready)
end

return M
