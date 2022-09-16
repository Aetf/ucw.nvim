local M = {}

M.url = 'hrsh7th/cmp-nvim-lsp'
M.description = 'Nvim LSP source for nvim-cmp'

M.requisite = {
  'nvim-cmp',
  'target.lsp',
}
M.after = {
  'nvim-cmp',
}

M.activation = {
  wanted_by = {
    'nvim-cmp',
    'target.lsp',
  }
}

function M.config()
  require('ucw.lsp').register_on_server_setup('.*', function(opts)
    local caps = opts.capabilities or vim.lsp.protocol.make_client_capabilities()
    opts.capabilities = require('cmp_nvim_lsp').update_capabilities(caps)
  end)
end

return M
