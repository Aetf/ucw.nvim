local M = {}

M.url = 'folke/trouble.nvim'
M.description = 'Fancy problem list'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  },
}

function M.config()
  require('trouble').setup {
    auto_close = true,
    auto_fold = true,
    use_diagnostic_signs = true,
  }

  -- key setup
end

return M
