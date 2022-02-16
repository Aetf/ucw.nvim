local M = {}

M.url = 'rcarriga/nvim-notify'
M.description = 'Sexy notification system'

M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config ()
  local notify = require('notify')
  notify.setup {
    --background_colour = '#B0BeC500',
  }
  vim.notify = notify
end

return M
