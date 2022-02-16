local M = {}

M.url = 'hrsh7th/cmp-nvim-lsp'
M.description = 'Nvim LSP source for nvim-cmp'

M.requires = {
  'nvim-cmp',
  'target.lsp',
}

function M.config()
  local caps = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  require('ucw.lsp').setup_common({
    capabilities = caps
  })
end

return M
