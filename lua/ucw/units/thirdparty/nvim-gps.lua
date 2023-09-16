---@type nvimd.Unit
local M = {}

M.url = 'SmiteshP/nvim-gps'
M.description = 'Show location in statusline based on treesitter'
-- TODO(replace with nvim-navic)
M.disabled = true

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
