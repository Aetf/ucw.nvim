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
end

return M
