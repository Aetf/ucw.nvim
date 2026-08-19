return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. The plugin was
  -- already lazy on `cmd`; the key now also lazy-load-triggers it, so at boot
  -- the mapping is lazy.nvim's stub (callback) rather than the raw string.
  keys = {
    { '<leader>gg', '<cmd>Neogit<cr>', desc = 'Neogit', silent = true },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- kept in sync with lua/ucw/plugins/diffview.lua's fork switch - two
    -- copies under the same `diffview` module name would silently conflict
    -- on rtp order.
    'dlyongemallo/diffview-plus.nvim',
  },
  config = function()
    local neogit = require('neogit')

    neogit.setup {
      -- then this will use vim.nofity, which will use our fancy floating notification system
      disable_builtin_notifications = true,
      disable_commit_confirmation = true,
      integrations = {
        diffview = true,
      },
      mappings = {
        -- for the status buffer
        status = {
          ['<ESC>'] = 'Close',
        },
      },
    }
  end,
}
