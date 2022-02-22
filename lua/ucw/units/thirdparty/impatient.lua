---@type nvimd.Unit
local M = {}

M.url = 'lewis6991/impatient.nvim'
M.description = 'Speed up lua module loading'

M.no_default_dependencies = true
M.activation = {
  wanted_by = {
    'target.base'
  }
}

return M
