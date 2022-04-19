local M = {}

function M.on_server_ready(server, opts)
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  opts.capabilities = capabilities
end

return M
