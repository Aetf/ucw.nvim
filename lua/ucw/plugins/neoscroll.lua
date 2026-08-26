return {
  'karb94/neoscroll.nvim',
  lazy = false,
  config = function()
    require('neoscroll').setup {
      stop_eof = false,
    }
  end,
}
