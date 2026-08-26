-- Merged over nvim-lspconfig's `lsp/lua_ls.lua`, which supplies cmd,
-- filetypes and root_markers. Table fields only, like every file in this
-- directory: a function field here replaces the upstream one outright rather
-- than composing with it. (lua_ls happens to define none today - only an
-- `on_init` *example* in its docstring - but the rule is what the test
-- enforces, not the current contents of one upstream file.)
--
-- `workspace.library` is deliberately absent. It used to be
-- `nvim_get_runtime_file('', true)` - the entire Neovim runtime plus every
-- installed plugin, indexed up front on every Lua buffer. lazydev.nvim
-- (lua/ucw/plugins/lazydev.lua) adds only the paths a file actually
-- `require`s, on demand.
return {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        -- vim additionally loads modules by appending `lua` to a runtime path
        path = { 'lua/?.lua', 'lua/?/init.lua', '?.lua', '?/init.lua' },
        -- only search the first level of directories
        -- (the old module spelled this `ppathStrict`, which lua_ls ignores)
        pathStrict = true,
      },
      diagnostics = {
        -- `MiniIcons` is a real global this config uses (mini.nvim sets it up
        -- eagerly); without it, editing lua/ucw/plugins/mini.lua reports
        -- undefined-global on lines that are correct
        globals = { 'vim', 'MiniIcons' },
      },
      telemetry = {
        enable = false,
      },
    },
  },
}
