return {
  'hrsh7th/cmp-nvim-lsp',
  event = 'User UcwLspEnable',
  dependencies = { 'hrsh7th/nvim-cmp' },
  config = function()
    require('ucw.lsp').register_on_server_setup('.*', function(opts)
      local caps = opts.capabilities or vim.lsp.protocol.make_client_capabilities()
      opts.capabilities = vim.tbl_deep_extend('force', caps, require('cmp_nvim_lsp').default_capabilities())
    end)
  end,
}
