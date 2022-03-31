local M = {}

M.url = 'pwntester/octo.nvim'
M.description = 'Edit and review GitHub issues and pull requests from the comfort of your favorite editor'

M.requires = {
  'plenary',
}
M.wants = {
  'telescope',
  'nvim-web-devicons',
}

M.activation = {
  cmd = "Octo"
}

function M.config ()
  require('octo').setup {
  }
end

return M
