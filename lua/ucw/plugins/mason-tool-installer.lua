-- The complement of `ucw.lsp.servers`: binaries this config needs installed
-- but does not start as a language server, and which are therefore invisible
-- to that list -> `mason-lspconfig`'s `ensure_installed`
-- (lua/ucw/plugins/mason-lspconfig.lua). Anything install-only belongs here,
-- so that `ucw.lsp.servers` never has to grow a second, parallel list of
-- things that are not servers.
--
-- `ruff`/`taplo` are deliberately absent: both are dual-purpose binaries
-- already installed as LSP servers by that pipeline, and listing them again
-- would just be two installers racing to write the same `mason/bin/` entry.
return {
  'WhoIsSethDaniel/mason-tool-installer.nvim',
  cond = require('ucw.targets').is_full_ui,
  event = 'VeryLazy',
  dependencies = { 'williamboman/mason.nvim' },
  opts = {
    ensure_installed = {
      'stylua',
      -- Uninstallable on this machine today (Mason's prettier comes from npm,
      -- and this environment has none), and declared anyway: this list says
      -- what an editing session needs, not what the host happens to have. The
      -- day `npm` is reachable it installs itself - and markdown starts being
      -- reformatted on save, an intended behaviour arriving by surprise
      -- (docs/design/phase6.5-binary-deps.md §6).
      'prettier',
      -- Installed but deliberately never `vim.lsp.enable()`d. rustaceanvim
      -- starts this client itself; a second one is what used to attach twice
      -- to every Rust buffer, which is why `rust_analyzer` is absent from
      -- `ucw.lsp.servers`. What went unnoticed for four years is that the same
      -- absence was also the only thing that would have *installed* it: this
      -- machine ran an Oct 2022 build the whole time, and nothing could
      -- notice, because the declared set and the installed set were never
      -- compared (§3.1).
      --
      -- Declaring it fixes a fresh machine and does *not* replace the copy on
      -- one that already has it - neither runtime installer ever updates an
      -- already-installed package (`auto_update = false`, §3.2). That is what
      -- `:checkhealth ucw`'s "installed, and behind" state is for.
      'rust-analyzer',
    },
  },
}
