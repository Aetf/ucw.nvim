local M = {}

M.url = 'simrat39/rust-tools.nvim'
M.description = 'Extra functionality for rust-analyzer'

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
  -- Initialize the LSP via rust-tools instead
  require('mason-lspconfig').setup_handlers({
    ['rust_analyzer'] = function()
      require('rust-tools').setup{}
    end
  })
end

return M
