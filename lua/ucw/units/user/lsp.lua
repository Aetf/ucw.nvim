---@type nvimd.Unit
local M = {}

M.requires = {
    'plenary',
    'lspconfig',
    'mason-lspconfig',
}
M.after = {
    'plenary',
    'lspconfig',
    'mason-lspconfig',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('ucw.lsp').config()
  require('ucw.lsp').activate()
  -- reload current buffer for all LSP clients to attach
  vim.cmd('LspStart')
end

return M
