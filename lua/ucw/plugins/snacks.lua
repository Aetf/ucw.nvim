-- Mostly used for its vim.ui.input impl
return {
  'folke/snacks.nvim',
  lazy = false,
  dependencies = { 'echasnovski/mini.nvim' },
  config = function()
    require('snacks').setup {
      input = { enabled = true },
      picker = {
        ui_select = true,
      }
    }
  end,
}
