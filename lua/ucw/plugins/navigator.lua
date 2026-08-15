return {
  'Aetf/Navigator.nvim',
  -- `keys` alone would flip the spec to lazy-loading; keep the plugin eager as
  -- it has always been (Phase 8 relocates registration, not load triggers).
  lazy = false,
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. The h/j/k/l and
  -- `<M-Bslash>` maps have always existed in both normal and terminal mode;
  -- tab movement is normal-mode only.
  keys = {
    { '<M-Bar>', "<cmd>lua require('Navigator').tablast()<cr>", desc = 'Go to last tab' },
    { '<M-n>', "<cmd>lua require('Navigator').tabnext()<cr>", desc = 'Go to next tab' },
    { '<M-p>', "<cmd>lua require('Navigator').tabprev()<cr>", desc = 'Go to previous tab' },
    { '<M-Bslash>', "<cmd>lua require('Navigator').previous()<cr>", desc = 'Go to last window', mode = { 'n', 't' } },
    { '<M-h>', "<cmd>lua require('Navigator').left()<cr>", desc = 'Go to left window', mode = { 'n', 't' } },
    { '<M-j>', "<cmd>lua require('Navigator').down()<cr>", desc = 'Go to down window', mode = { 'n', 't' } },
    { '<M-k>', "<cmd>lua require('Navigator').up()<cr>", desc = 'Go to up window', mode = { 'n', 't' } },
    { '<M-l>', "<cmd>lua require('Navigator').right()<cr>", desc = 'Go to right window', mode = { 'n', 't' } },
  },
  config = function()
    -- `mux` is annotated required but is optional in practice: Navigator picks
    -- the multiplexer itself when it is not given (that is the whole point of
    -- its auto-detection), which is what this config wants.
    ---@diagnostic disable-next-line: missing-fields
    require('Navigator').setup {
      auto_save = 'all',
      disable_on_zoom = true,
    }
  end,
}
