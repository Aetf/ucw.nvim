-- Neovim-aware workspace library for lua_ls.
--
-- Replaces `after/lsp/lua_ls.lua` setting `workspace.library` to
-- `nvim_get_runtime_file('', true)` - the entire Neovim runtime plus every
-- installed plugin, handed to lua_ls up front on every Lua buffer. lazydev
-- watches for `require('...')` and `---@module` in the file being edited and
-- adds only those paths, on demand.
return {
  'folke/lazydev.nvim',
  cond = require('ucw.targets').is_full_ui,
  ft = 'lua',
  opts = {},
}
