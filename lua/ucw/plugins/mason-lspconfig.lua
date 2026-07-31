-- Kept for exactly one thing: it owns the server-name -> Mason-package mapping
-- (`lua_ls` -> `lua-language-server`, `ltex_plus` -> `ltex-ls-plus`, `jsonls` ->
-- `json-lsp`, ...), which turns `ucw.lsp.servers` into installation in one line.
--
-- `automatic_enable = false` is the fix for the duplicate rust-analyzer: the
-- default enables every *installed* server, which started a second
-- `rust_analyzer` alongside the one rustaceanvim owns, so both advertised
-- inlayHintProvider and every hint rendered twice. `vim.lsp.enable()` is called
-- from `ucw.lsp.setup()` against an explicit list instead.
--
-- `VeryLazy`, not the LSP `ft` trigger: setup costs 8-23 ms depending on how
-- warm the Mason registry cache is, and none of it is needed to get a client
-- attached, so it stays off the file-open path. It cannot ride `LspAttach`
-- either - a server that is not installed never attaches, so ensure_installed
-- would never run for exactly the servers that need it.
return {
  'williamboman/mason-lspconfig.nvim',
  cond = require('ucw.targets').is_full_ui,
  event = 'VeryLazy',
  -- deliberately does NOT depend on nvim-lspconfig: with automatic_enable off,
  -- everything it does here goes through the Mason registry, and declaring the
  -- dependency would force-load nvim-lspconfig at VeryLazy and undo the `ft`
  -- gating that keeps LSP off the startup path.
  dependencies = { 'williamboman/mason.nvim' },
  -- `opts` rather than a `config` function so the settings stay inspectable
  -- without loading the plugin - tests/test_lsp.lua asserts `automatic_enable`
  -- is off and `ensure_installed` tracks `ucw.lsp.servers`, and loading
  -- mason-lspconfig for real inside a test would start downloading language
  -- servers.
  opts = {
    automatic_enable = false,
    ensure_installed = require('ucw.lsp').server_names(),
  },
}
