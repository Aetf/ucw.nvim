local function toggle()
  local new_value = not vim.diagnostic.config().virtual_lines
  if new_value then
    new_value = {
      only_current_line = true
    }
  end
  vim.diagnostic.config {
    virtual_lines = new_value
  }
end

return {
  'https://git.sr.ht/~whynothugo/lsp_lines.nvim',
  event = 'User UcwLspEnable',
  config = function()
    require('lsp_lines').setup()

    vim.diagnostic.config {
      virtual_lines = {
        only_current_line = true
      }
    }

    vim.keymap.set("", "<leader>lp", toggle, {
      desc = 'Toggle lsp_lines'
    })
  end,
}
