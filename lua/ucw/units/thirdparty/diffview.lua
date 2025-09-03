local M = {}

M.url = 'sindrets/diffview.nvim'
M.description = 'Single tabpage interface for easily cycling through diffs for all modified files for any git rev.'

M.wants = {
  'plenary',
  'mini-icons',
}
M.after = {
  'plenary',
}

-- ways to activate this
M.activation = {
  cmd = {
    'DiffviewOpen',
    'DiffviewFileHistory',
    'DiffviewLog',
  },
  modules = 'diffview',
}

function M.config()
  require('diffview').setup {}
end


return M
