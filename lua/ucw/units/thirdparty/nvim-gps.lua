---@type nvimd.Unit
local M = {}

M.url = 'SmiteshP/nvim-gps'
M.description = 'Show location in statusline based on treesitter'

M.requires = {
  'treesitter',
}
M.after = {
  'treesitter',
}

function M.config()
  require('nvim-gps').setup { }
end

return M
