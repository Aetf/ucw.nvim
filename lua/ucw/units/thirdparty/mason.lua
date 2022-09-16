local M = {}

M.url = 'williamboman/mason.nvim'
M.description = 'Portable package manager for Neovim that runs everywhere Neovim runs. Easily install and manage LSP servers, DAP servers, linters, and formatters.'

M.requires = {
}
M.after = {
}

M.activation = {
  wanted_by = {
    'target.basic',
  }
}

function M.config()
  require('mason').setup()
end

return M
