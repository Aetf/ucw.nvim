local M = {}

M.url = 'tpope/vim-fugitive'
M.description = 'Git'

M.wants = {
}
M.after = {
}

M.activation = {
  cmd = {
    'G',
    'Git',
  },
}

M.config = function()
end

return M
