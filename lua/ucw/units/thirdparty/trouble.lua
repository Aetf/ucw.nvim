local M = {}

M.url = 'folke/trouble.nvim'
M.description = 'Fancy problem list'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('trouble').setup {
    auto_close = true,
    auto_fold = true,
  }
end

return M
