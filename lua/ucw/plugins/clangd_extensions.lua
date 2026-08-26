-- clangd itself is enabled through `ucw.lsp.servers` like every other server;
-- this only adds the bits that are not in the LSP spec (switch source/header,
-- AST view, type hierarchy, memory usage).
--
-- Until Phase 3 this plugin loaded on every LSP activation while clangd was
-- never actually enabled - mason-lspconfig only auto-enabled servers Mason had
-- installed, and clangd was not one of them. Its `ft` list mirrors clangd's.
return {
  'p00f/clangd_extensions.nvim',
  cond = require('ucw.targets').is_full_ui,
  ft = require('ucw.lsp.servers').clangd,
  config = function()
    require('clangd_extensions').setup {}
  end,
}
