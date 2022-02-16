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
  require('ucw.lsp').custom_server_setup('rust_analyzer', function(server, opts)
    -- Initialize the LSP via rust-tools instead
    require("rust-tools").setup {
	-- The "server" property provided in rust-tools setup function are the
	-- settings rust-tools will provide to lspconfig during init.
	-- We merge the necessary settings from nvim-lsp-installer (server:get_default_options())
	-- with the user's own settings (opts).
	server = vim.tbl_deep_extend("force", server:get_default_options(), opts),
    }
    server:attach_buffers()
  end)
end

return M
