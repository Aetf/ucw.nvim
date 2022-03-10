---@type nvimd.Unit
local M = {}

M.requires = {
    'plenary',
    'lsp-installer',
}
M.after = {
    'plenary',
    'lsp-installer',
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
