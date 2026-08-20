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
    -- the diff viewer neogit hands off to; see lua/ucw/plugins/codediff.lua
    -- for why it is codediff and not diffview.
    'esmuellert/codediff.nvim',
  },
  config = function()
    local neogit = require('neogit')

    neogit.setup {
      -- then this will use vim.nofity, which will use our fancy floating notification system
      disable_builtin_notifications = true,
      disable_commit_confirmation = true,
      integrations = {
        codediff = true,
      },
      -- neogit auto-detects diffview first and only then codediff; be explicit
      -- so the choice does not depend on what else happens to be installed.
      diff_viewer = 'codediff',
      mappings = {
        -- for the status buffer
        status = {
          ['<ESC>'] = 'Close',
        },
      },
    }
  end,
}
