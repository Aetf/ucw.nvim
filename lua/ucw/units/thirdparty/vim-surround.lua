local M = {}

M.url = 'tpope/vim-surround'
M.description = 'vim-surround'

M.wants = {
  'vim-repeat'
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.setup()
  vim.g.surround_no_insert_mappings = 1
  -- latex command, similar to function
  vim.g['surround_' .. vim.fn.char2nr('c')] = "\\\1command\1{\r}"
end

return M
