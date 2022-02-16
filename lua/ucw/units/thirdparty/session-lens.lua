local M = {}

M.url = 'rmagatti/session-lens'
M.description = 'Telescope picker for sessions'

M.requires = {
  'auto-session',
  'telescope',
}
M.after = {
  'auto-session',
  'telescope',
}

function M.config()
  require('session-lens').setup {
    previewer = false
  }
end

return M
