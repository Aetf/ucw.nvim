return {
  'mrcjkb/rustaceanvim',
  event = 'User UcwLspEnable',
  dependencies = { 'williamboman/mason-lspconfig.nvim' },
  init = function()
    local lsp = require('ucw.lsp')
    lsp.register_on_attach('rust_analyzer', function(client, bufnr)
      -- override code action to a more useful one
      vim.keymap.set(
        "n",
        "<leader>a",
        function()
          vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
        end,
        { silent = true, buffer = bufnr }
      )
    end)

    -- rustaceanvim uses its own lsp client, not through lspconfig, so most
    -- ucw.hooks doesn't work except on_attach.
    -- fortunately, most plugin integrations are already done in rustaceanvim,
    -- including cmp-lsp-info, ufo, loading vscode settings
    vim.g.rustaceanvim = {
      tools = {},
      server = {
        load_vscode_settings = true,
        default_settings = {
          ['rust-analyzer'] = {},
        },
      },
      dap = {},
    }
  end,
}
