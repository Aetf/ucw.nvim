local M = {}

M.url = 'hrsh7th/cmp-nvim-lsp-signature-help'
M.description = 'Signature help source for nvim-cmp'

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

return M
