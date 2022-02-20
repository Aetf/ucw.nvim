local M = {}

M.url = 'Aetf/Navigator.nvim'
M.description = 'Use the same key for window/tab nagivation, also requires tmux config'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  require('Navigator').setup {
    auto_save = 'all',
    disable_on_zoom = true,
  }
end

return M
