local M = {}

M.url = 'GCBallesteros/vim-textobj-hydrogen'
M.description = 'Text object for ipython cell'

M.requires = {
  'textobj-user'
}
M.after = {
  'textobj-user'
}
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

return M
