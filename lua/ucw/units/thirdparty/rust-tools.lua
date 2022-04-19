local M = {}

M.url = 'simrat39/rust-tools.nvim'
M.description = 'Extra functionality for rust-analyzer'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  require('ucw.lsp').register_server_setup('rust_analyzer', function(server, opts)
    -- Initialize the LSP via rust-tools instead
    require("rust-tools").setup {
      server = opts,
    }
    server:attach_buffers()
  end)
end

return M
