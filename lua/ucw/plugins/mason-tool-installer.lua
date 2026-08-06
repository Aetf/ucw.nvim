-- Installs formatter-only binaries that have no LSP counterpart, and so are
-- structurally invisible to `ucw.lsp.servers` -> `mason-lspconfig`'s own
-- `ensure_installed` (lua/ucw/plugins/mason-lspconfig.lua). `ruff`/`taplo` are
-- deliberately absent here: both are dual-purpose binaries already installed
-- as LSP servers by that pipeline, and listing them again would just be two
-- installers racing to write the same `mason/bin/` entry.
return {
  'WhoIsSethDaniel/mason-tool-installer.nvim',
  cond = require('ucw.targets').is_full_ui,
  event = 'VeryLazy',
  dependencies = { 'williamboman/mason.nvim' },
  opts = {
    ensure_installed = { 'stylua', 'prettier' },
  },
}
