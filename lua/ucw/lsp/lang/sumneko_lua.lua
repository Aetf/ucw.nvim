local utils = require('ucw.utils')
local lu = require('ucw.lsp.utils')

local M = {}

function M.on_server_setup(opts)
  opts.root_dir = lu.lazy_root_pattern('.git', 'stylua.toml', '.stylua.toml')
  -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
  utils.prop_set(opts, 'settings.Lua.runtime.version', 'LuaJIT')
  -- vim will additionally load modules from its runtime path by appending `lua`
  utils.prop_set(opts, 'settings.Lua.runtime.path', {'lua/?.lua', 'lua/?/init.lua', '?.lua', '?/init.lua'})
  -- only search first level of directories
  utils.prop_set(opts, 'settings.Lua.runtime.ppathStrict', true)
  -- Get the language server to recognize the `vim` global
  utils.prop_set(opts, 'settings.Lua.diagnostics.globals', {'vim'})
  -- Make the server aware of Neovim runtime files
  utils.prop_set(opts, 'settings.Lua.workspace.library', vim.api.nvim_get_runtime_file("", true))
  -- Do not send telemetry data containing a randomized but unique identifier
  utils.prop_set(opts, 'settings.Lua.telemetry.enable', false)
end

return M
