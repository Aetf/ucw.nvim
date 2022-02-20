local M = {}

M.url = 'rmagatti/session-lens'
M.description = 'Telescope picker for sessions'

M.requisite = {
  'auto-session',
  'telescope',
}
M.after = {
  'auto-session',
  'telescope',
}
M.activation = {
  wanted_by = {
    'telescope',
    'auto-session',
  }
}

function M.config()
  require('session-lens').setup {
    previewer = false
  }
end

return M
