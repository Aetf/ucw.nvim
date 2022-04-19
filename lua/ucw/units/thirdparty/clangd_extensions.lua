local M = {}

M.url = 'p00f/clangd_extensions.nvim'
M.description = 'Extra functionality for clangd'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('ucw.lsp').register_server_setup('clangd', function(server, opts)
    -- Initialize the LSP via clangd_extensions
    require('clangd_extensions').setup {
      server = opts,
    }
    server:attach_buffers()
  end)
end

return M
