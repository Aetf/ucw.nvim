-- nvim-lspconfig is kept installed **only** as a passive data source: its
-- bundled `lsp/<name>.lua` registry supplies cmd/filetypes/root_markers for 400+
-- servers and native `vim.lsp.config` merges them by itself. It is never
-- `require`d, and none of its setup functions are called - upstream deprecated
-- that framework in favour of `vim.lsp.config()`/`vim.lsp.enable()` anyway.
--
-- This spec is also where the LSP subsystem comes up. `ft` is the whole
-- activation model: opening a file of a supported type loads this plus mason
-- (only for its bin/ on PATH) and runs `ucw.lsp.setup()`, which calls
-- `vim.lsp.enable()`. lazy.nvim replays the FileType event after this `config`
-- returns, so the buffer that triggered the load gets its client without any
-- manual `doautocmd`.
--
-- Measured on the finished implementation, not on the design sketch: this
-- whole trigger is ~3 ms (mason 1.2 of it), or ~6 ms counting the config
-- resolution and client start for the buffer that triggered it. For scale, the
-- first file opened in a session costs ~27 ms before any of this - treesitter,
-- gitsigns, ufo, statusline - even for a plain .txt with no LSP at all.
--
-- The two expensive plugins are deliberately NOT here: mason-lspconfig (8-23 ms,
-- depending on how warm its registry cache is) sits on `VeryLazy`, and
-- lsp-progress (3-12 ms) on `LspAttach`. Neither is needed to get a client
-- attached. See docs/design/phase3-lsp-redesign.md §3.
return {
  'neovim/nvim-lspconfig',
  cond = require('ucw.targets').is_full_ui,
  ft = require('ucw.lsp').filetypes(),
  dependencies = { 'williamboman/mason.nvim' },
  config = function()
    require('ucw.lsp').setup()
    require('ucw.lsp.ltex_dict').setup()
  end,
}
