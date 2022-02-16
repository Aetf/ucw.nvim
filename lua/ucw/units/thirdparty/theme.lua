local M = {}

M.url = 'fnune/base16-vim'
M.description = 'A lovely theme'

M.activation = {
  wanted_by = {
    'target.base'
  }
}

function M.config()
  vim.cmd [[colorscheme base16-eighties]]
end

return M
