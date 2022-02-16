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
  require('ucw.lsp').custom_server_setup('clangd', function(server, opts)
    -- Initialize the LSP via clangd_extensions
    require('clangd_extensions').setup {
      server = vim.tbl_deep_extend('force', server:get_default_options(), opts),
    }
    server:attach_buffers()
  end)
end

return M
