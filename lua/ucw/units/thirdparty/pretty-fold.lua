local M = {}

M.url = 'anuvyklack/pretty-fold.nvim'
M.description = 'Preetier folding line and preview window'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('pretty-fold').setup{
    fill_char = ' ',
    process_comment_signs = false,
    add_close_pattern = true,
  }
  --[[
  require('pretty-fold.preview').setup {
    key = 'h',
  }
  --]]
end

return M
