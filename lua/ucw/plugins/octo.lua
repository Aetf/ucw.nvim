return {
  'pwntester/octo.nvim',
  cmd = 'Octo',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'folke/snacks.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    -- octo defaults to `telescope`, which Phase 5 removed. The enum is
    -- validated (`octo/config.lua`, `validate_pickers`), so a stale value here
    -- would be a startup error rather than a silent fallback.
    require('octo').setup { picker = 'snacks' }
    local wk = require('which-key')
    wk.register {
      ['<leader>g'] = {
        o = {
          name = "+octo (GitHub)",
          o = { [[<cmd>Octo actions<cr>]], "Pick an action" },
          i = { [[<cmd>Octo issue search<cr>]], "Search issues" },
          p = { [[<cmd>Octo pr search<cr>]], "Search issues" },
        }
      }
    }
  end,
}
