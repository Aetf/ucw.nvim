local M = {}

M.url = 'rcarriga/nvim-notify'
M.description = 'Sexy notification system'

M.activation = {
  wanted_by = {
    'target.basic'
  }
}
---------------------------------------------------------------------------------------------------
function M.config ()
  local notify = require('notify')
  notify.setup {
    --background_colour = '#B0BeC500',
    timeout = 3000,
    max_width = 55,
    min_width = 30,
  }
  vim.notify = notify
end

return M
