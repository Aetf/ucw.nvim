return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewLog' },
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. Same shape as
  -- neogit: already lazy on `cmd`, the key becomes an additional trigger.
  keys = {
    { '<leader>gh', '<cmd>DiffviewFileHistory<CR>', desc = 'History for current buffer', silent = true },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    require('diffview').setup {}
  end,
}
