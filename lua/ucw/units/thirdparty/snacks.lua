local M = {}

M.url = 'folke/snacks.nvim'

-- Mostly used for its vim.ui.input impl
M.description = 'A collection of QoL plugins for Neovim'

M.wants = {
  'mini-icons', -- icons
}

M.requires = {
}
M.after = {
  'mini-icons', -- icons
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  require('snacks').setup {
    input = { enabled = true },
    picker = {
      ui_select = true,
    }
  }
end

return M
