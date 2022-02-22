---@type nvimd.Unit
local M = {}

M.url = 'antoinemadec/FixCursorHold.nvim'
M.description = 'Fix slowness in CursorHold'

M.no_default_dependencies = true
M.activation = {
  wanted_by = {
    'target.base',
  },
}

function M.config()
  -- in ms
  vim.g.cursorhold_updatetime = 100
end

return M
