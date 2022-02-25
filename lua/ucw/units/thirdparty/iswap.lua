---@type nvimd.Unit
local M = {}

M.url = 'mizlan/iswap.nvim'
M.description = 'Swap function arguments'

M.activation = {
  cmd = {
    'ISwapWith',
    'ISwap',
  }
}

function M.config()
  require('iswap').setup {
  }
end

return M
