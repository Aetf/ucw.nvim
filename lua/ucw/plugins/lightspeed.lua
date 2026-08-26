local map = require('ucw.utils').map

return {
  'ggandor/lightspeed.nvim',
  lazy = false,
  dependencies = { 'tpope/vim-repeat' },
  config = function()
    -- use bidirection s
    map('n', 's', '<Plug>Lightspeed_omni_s', { noremap = false })
    map('n', 'gs', '<Plug>Lightspeed_omni_gs', { noremap = false })
  end,
}
