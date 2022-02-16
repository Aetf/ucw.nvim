local M = {}

M.description = 'Basic editing experience'

M.requires = {
  'target.base',
}
M.wants = {
  'target.mapping',
  'target.completion',
}

return M
