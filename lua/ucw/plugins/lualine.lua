return {
  'nvim-lualine/lualine.nvim',
  lazy = false,
  dependencies = { 'echasnovski/mini.nvim' },
  config = function()
    require('lualine').setup {
      extensions = {
        'quickfix',
        {
          filetypes = { "neo-tree" },
          sections = {
            lualine_a = {
              function() return vim.fn.fnamemodify(vim.fn.getcwd(), ':~') end,
            }
          }
        }
      },
    }
  end,
}
