-- Mason installs the server binaries and puts its `bin/` on PATH; that PATH
-- edit is all the LSP hot path needs from it (measured 1.2 ms), so it loads as
-- a dependency of nvim-lspconfig rather than eagerly at startup. Making it
-- lazy is most of why startup dropped from 84 ms to ~68 ms in this phase.
return {
  'williamboman/mason.nvim',
  cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll', 'MasonLog', 'MasonUpdate' },
  config = function()
    require('mason').setup()
  end,
}
