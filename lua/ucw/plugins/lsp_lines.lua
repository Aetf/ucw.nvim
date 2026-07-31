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
  cond = require('ucw.targets').is_full_ui,
  -- The `User UcwLspEnable` event this used to ride is gone with `<leader>ll`;
  -- diagnostics only exist once something attached anyway. Phase 4 is expected
  -- to delete this plugin outright - its rendering is 100% native
  -- `vim.diagnostic.config { virtual_lines = ... }` now.
  event = 'LspAttach',
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
