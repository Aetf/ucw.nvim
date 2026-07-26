return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
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
          ["<ESC>"] = "Close",
        },
      },
    }
  end,
}
