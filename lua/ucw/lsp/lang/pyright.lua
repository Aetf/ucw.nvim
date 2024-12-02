local utils = require('ucw.utils')

local M = {}

function M.on_server_setup(opts)
  -- Enable lsp client side file watching. It is needed by pyright which doesn't
  -- do its own watching. https://github.com/microsoft/pyright/issues/4635
  -- Note that watching can be expensive on large repos.
  -- See https://github.com/neovim/neovim/issues/23291
  opts.capabilities = opts.capabilities or vim.lsp.protocol.make_client_capabilities()
  opts.capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
end

return M
