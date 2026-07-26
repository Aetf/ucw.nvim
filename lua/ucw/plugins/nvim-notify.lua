return {
  'rcarriga/nvim-notify',
  lazy = false,
  config = function()
    local notify = require('notify')
    notify.setup {
      timeout = 3000,
      max_width = 55,
      min_width = 30,
    }
    vim.notify = notify

    -- trigger a notify loaded autocmd, such that any pending notify calls before
    -- nvim-notify is loaded can be displayed (e.g. in structlog)
    vim.api.nvim_exec_autocmds('User', { pattern = 'NotifyLoaded' })
  end,
}
