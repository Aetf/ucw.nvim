local M = {}

M.url = 'WhoIsSethDaniel/lualine-lsp-progress.nvim'
M.description = 'LSP progress lualine component'

M.requisite = {
  'target.lsp',
  'lualine',
}
M.after = {
  'lualine',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'lualine',
    'target.lsp'
  }
}

function M.config()
  local utils = require('ucw.utils')

  -- update lualine to include the component
  local lualine = require('lualine')
  local config = lualine.get_config()
  table.insert(config.sections.lualine_x, 1, {
    'lsp_progress',
  })

  -- faster refresh for lsp progress spinner
  utils.prop_set(config, 'options.refresh.statusline', 100)

  -- apply lualine config
  lualine.setup(config)
end

return M
