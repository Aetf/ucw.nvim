---@type nvimd.Unit
local M = {}

M.url = 'karb94/neoscroll.nvim'
M.description = 'Smooth scroll using window movement commands'

M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  require('neoscroll').setup {
    stop_eof = false,
  }
end

return M
