return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  -- Phase 8 (D3): the last which-key v1 `wk.register` block in this config -
  -- the one file Phase 3's v1 -> v3 audit never opened (phase7-ci.md §7) -
  -- became these `keys =` entries. That closes the discoverability gap more
  -- fully than the plan's eager-group-header prescription alone: the keys are
  -- visible *and functional* before octo ever loads, as lazy-load triggers
  -- alongside `cmd`. The `<leader>go` group header is registered eagerly in
  -- `which-key.lua`. Descs are verbatim from the v1 block, including `pr
  -- search` labelled 'Search issues' - bindings and labels are Phase 9's.
  keys = {
    { '<leader>goo', '<cmd>Octo actions<cr>', desc = 'Pick an action', silent = true },
    { '<leader>goi', '<cmd>Octo issue search<cr>', desc = 'Search issues', silent = true },
    { '<leader>gop', '<cmd>Octo pr search<cr>', desc = 'Search pull requests', silent = true },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'folke/snacks.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    -- octo defaults to `telescope`, which Phase 5 removed. The enum is
    -- validated (`octo/config.lua`, `validate_pickers`), so a stale value here
    -- would be a startup error rather than a silent fallback.
    require('octo').setup { picker = 'snacks' }
  end,
}
