local M = {}

M.url = 'p00f/clangd_extensions.nvim'
M.description = 'Extra functionality for clangd'

M.after = {
  'mason-lspconfig',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  lsp = require('ucw.lsp')
  -- Initialize the LSP via clangd_extensions
  lsp.register_on_setup_handler('clangd', function()
    require('clangd_extensions').setup{}
    -- prevent further hook processing
    return true
  end)
end

return M
