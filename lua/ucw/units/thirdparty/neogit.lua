local M = {}

M.url = 'TimUntersberger/neogit'
M.description = 'Git Text UI'

M.wants = {
  'plenary',
  'diffview',
}
M.after = {
  'plenary',
}

M.activation = {
  cmd = {
    'Neogit',
  },
}

M.config = function()
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
end

return M
