local M = {}

M.url = 'dstein64/vim-startuptime'
M.description = 'Measure and view vim startup time'

M.activation = {
  cmd = 'StartupTime',
}

function M.config()
  vim.g.startuptime_exe_args = {
    '.'
  }
  vim.g.startuptime_tries = 5
end

return M
