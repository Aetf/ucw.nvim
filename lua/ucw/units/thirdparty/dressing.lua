local M = {}

M.url = 'stevearc/dressing.nvim'
M.description = 'Use telescope for vim.ui'

M.requires = {
  'telescope',
}
M.after = {
  'telescope',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'telescope'
  }
}

local au = require('au')

function M.config()
  vim.cmd [[hi link FloatBorder Normal]]
  require('dressing').setup {
    input = {
      win_options = {
        winblend = 0,
      }
    },
    select = {
      get_config = function(opts)
        if opts.kind == 'codeaction' then
          return {
            telescope = {
              theme = 'cursor',
            }
          }
        end
      end
    }
  }
end

return M
