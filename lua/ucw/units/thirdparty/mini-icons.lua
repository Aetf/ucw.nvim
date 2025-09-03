local M = {}

M.description = 'icon provider'

M.requires = {
  'mini',
}
M.after = {
  'mini',
}
M.wants = {
}

M.activation = {
  wanted_by = {
    -- LSP will call this to tweak lsp kind
    'target.lsp'
  }
}

function M.setup()
  require('mini.icons').setup{}
  -- Needed by neotree
  -- Needed by diffview
  -- Needed by octo
  -- Needed by bufferline
  -- Needed by telescope
  -- Needed by lualine
  MiniIcons.mock_nvim_web_devicons()
end

return M

