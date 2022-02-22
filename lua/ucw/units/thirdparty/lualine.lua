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
      'quickfix',
      {
        filetypes = {"neo-tree"},
        sections = {
          lualine_a = {
            function() return vim.fn.fnamemodify(vim.fn.getcwd(), ':~') end,
          }
        }
      }
    },
  }
end

return M
