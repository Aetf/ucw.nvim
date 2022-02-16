local lu = require('ucw.lsp.utils')

return {
  root_dir = lu.lazy_root_pattern('.git', 'stylua.toml', '.stylua.toml'),
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
        -- vim will additionally load modules from its runtime path by appending `lua`
        path = {'lua/?.lua', 'lua/?/init.lua', '?.lua', '?/init.lua'},
        -- only search first level of directories
        pathStrict = true,
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}
