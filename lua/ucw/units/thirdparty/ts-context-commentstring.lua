local M = {}

M.url = 'JoosepAlviste/nvim-ts-context-commentstring'
M.description = 'Set commentstring based on ts'

M.after = {
  'treesitter',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'treesitter'
  }
}

function M.config()
  vim.g.skip_ts_context_commentstring_module = true
  require('ts_context_commentstring').setup {}
end

return M
