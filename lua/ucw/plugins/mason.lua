-- Mason installs the server binaries and puts its `bin/` on PATH; that PATH
-- edit is all the LSP hot path needs from it (measured 1.2 ms), so it loads as
-- a dependency of nvim-lspconfig rather than eagerly at startup. Making it
-- lazy is most of why startup dropped from 84 ms to ~68 ms in this phase.
return {
  'williamboman/mason.nvim',
  cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll', 'MasonLog', 'MasonUpdate' },
  config = function()
    -- `append`, not Mason's own default of `prepend`: Mason is the
    -- compatibility floor, not the ceiling. Whatever the project this session
    -- was started in provides - `node_modules/.bin`, a `.venv`, a `mise.toml`
    -- (including this repo's own), `nix develop` - is already ahead on PATH,
    -- and it has to win, or an editor-wide install silently overrides a pin
    -- the project made deliberately.
    --
    -- One line, because PATH is the mechanism all of those already target:
    -- flipping it moves every consumer at once - conform's bare
    -- `command = 'stylua'`, `vim.lsp.config`'s `cmd`, rustaceanvim's
    -- `exepath('rust-analyzer')`, nvim-treesitter's `executable('tree-sitter')`
    -- - including the ones that do not exist yet. Nothing opts in, and there
    -- is no resolution chain of ours for anything to have to learn.
    --
    -- The limitation this accepts: PATH is process-global, so "the project"
    -- means the environment nvim was launched in, not the buffer under the
    -- cursor. `:checkhealth ucw` is the compensation - it prints the path each
    -- declared binary actually resolved to, so "this session is on the floor"
    -- is visible rather than discovered.
    -- docs/design/phase6.5-binary-deps.md §1, §2.2.
    require('mason').setup { PATH = 'append' }
  end,
}
