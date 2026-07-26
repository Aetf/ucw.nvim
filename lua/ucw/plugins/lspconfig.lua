-- Kept installed only as a passive data source for its bundled per-server
-- lsp/*.lua config registry, picked up automatically by native
-- vim.lsp.config merge. Never `require('lspconfig')` or call its setup
-- functions directly.
return {
  'neovim/nvim-lspconfig',
  event = 'User UcwLspEnable',
}
