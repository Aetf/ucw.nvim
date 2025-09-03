local M = {}

M.url = 'mrcjkb/rustaceanvim'
M.description = 'Supercharge your Rust experience in Neovim!'

M.requisite = {
  'mason-lspconfig',
}

M.after = {
  'mason-lspconfig',
}

M.before = {
  -- run before the lsp unit to make sure our setup handler is called first
  'lsp',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

-- setup runs before packadd
function M.setup()
  lsp = require('ucw.lsp')
  lsp.register_on_attach('rust_analyzer', function(client, bufnr)
    -- override code action to a more useful one
    vim.keymap.set(
      "n",
      "<leader>a",
      function()
        vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
        -- or vim.lsp.buf.codeAction() if you don't want grouping.
      end,
      { silent = true, buffer = bufnr }
    )
  end)

  -- rustaceanvim uses its own lsp client, not through lspconfig, so most
  -- ucw.hooks doesn't work except on_attach.
  -- fortunately, most plugin integrations are already done in rustaceanvim,
  -- including cmp-lsp-info, ufo, loading vscode settings
  vim.g.rustaceanvim = {
    -- Plugin configuration
    tools = {
    },
    -- LSP configuration
    server = {
      load_vscode_settings = true,
      default_settings = {
        -- rust-analyzer language server configuration
        ['rust-analyzer'] = {
        },
      },
    },
    -- DAP configuration
    dap = {
    },
  }
end

return M
