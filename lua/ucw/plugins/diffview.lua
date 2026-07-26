return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewLog' },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    require('diffview').setup {}
  end,
}
