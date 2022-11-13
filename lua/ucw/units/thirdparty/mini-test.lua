local M = {}

M.description = 'mini.test'

M.requires = {
  'mini',
}
M.after = {
  'mini',
}

function M.setup()
  require('mini.test').setup()
end

return M
