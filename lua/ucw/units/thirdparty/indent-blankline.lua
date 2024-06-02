local M = {}

M.url = 'lukas-reineke/indent-blankline.nvim'
M.description = 'Show indentation guide'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('ibl').setup {}
end

return M
