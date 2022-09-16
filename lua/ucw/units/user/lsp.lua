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
end

return M
