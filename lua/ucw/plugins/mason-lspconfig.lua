return {
  'williamboman/mason-lspconfig.nvim',
  event = 'User UcwLspEnable',
  dependencies = {
    'williamboman/mason.nvim',
    'neovim/nvim-lspconfig',
  },
  config = function()
    require('mason-lspconfig').setup {
      -- vim.lsp.enable all installed servers
      automatic_enable = true,
    }
  end,
}
