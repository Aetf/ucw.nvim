local M = {}

M.description = 'Integration between nvim-notify and telescope'

M.requisite = {
  'nvim-notify',
  'telescope',
}
M.after = {
  'nvim-notify',
  'telescope',
}

M.activation = {
  wanted_by = {
    'nvim-notify',
    'telescope',
  }
}

function M.config()
  require("telescope").load_extension("notify")
end

return M
