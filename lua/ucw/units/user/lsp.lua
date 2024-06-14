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
  vim.lsp.inlay_hint.enable()
  -- reload current buffer
  vim.cmd('e')
end

return M
