local M = {}

M.url = 'https://git.sr.ht/~whynothugo/lsp_lines.nvim'
M.description = 'Renders diagnostics using virtual lines on top of the real line of code.'

M.wants = {
}
M.after = {
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

local function toggle()
  local new_value = not vim.diagnostic.config().virtual_lines
  if new_value then
    new_value = {
      only_current_line = true
    }
  end
  vim.diagnostic.config{
    virtual_lines = new_value
  }
end

function M.config()
  require('lsp_lines').setup()

  vim.diagnostic.config{
    virtual_lines = {
      only_current_line = true
    }
  }

  vim.keymap.set("", "<leader>lp", toggle, {
    desc = 'Toggle lsp_lines'
  })
end


return M
