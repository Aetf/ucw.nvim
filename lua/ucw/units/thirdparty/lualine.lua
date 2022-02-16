local M = {}

M.url = 'nvim-lualine/lualine.nvim'
M.description = 'Statusline'

M.wants = {
  'nvim-web-devicons',
}

M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  require('lualine').setup {
    extensions = {
      'nvim-tree',
      'quickfix',
    },
  }
end

return M
