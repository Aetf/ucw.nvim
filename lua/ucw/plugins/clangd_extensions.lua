return {
  'p00f/clangd_extensions.nvim',
  event = 'User UcwLspEnable',
  dependencies = { 'williamboman/mason-lspconfig.nvim' },
  config = function()
    require('clangd_extensions').setup {}
  end,
}
