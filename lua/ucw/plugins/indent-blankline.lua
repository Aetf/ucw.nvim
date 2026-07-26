return {
  'lukas-reineke/indent-blankline.nvim',
  main = 'ibl',
  cond = require('ucw.targets').is_full_ui,
  config = function()
    require('ibl').setup {}
  end,
}
