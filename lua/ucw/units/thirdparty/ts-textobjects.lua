---@type nvimd.Unit
local M = {}

M.url = 'nvim-treesitter/nvim-treesitter-textobjects'
M.description = 'Textobject based on treesitter'

M.requisite = {
  'treesitter',
}
M.after = {
  'treesitter',
}

M.activation = {
  wanted_by = {
    'treesitter',
  }
}

return M
