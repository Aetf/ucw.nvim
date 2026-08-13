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
    -- The last which-key v1 caller in this config. It still works - v3 keeps
    -- `M.register` as a shim onto `M.add(mappings, { version = 1 })` - but the
    -- whole nested-table spec below is v1 shaped, so converting it is rewriting
    -- the block, not renaming the call. That is Phase 8's subject (keymap
    -- registration), and this is the one file Phase 3's audit of the v1 -> v3
    -- conversion never opened. When it converts, `tests/test_keys.lua`'s
    -- "no `desc` that looks like an rhs" assertion covers it for free.
    -- See docs/design/phase7-ci.md §7.
    ---@diagnostic disable-next-line: deprecated
    wk.register {
      ['<leader>g'] = {
        o = {
          name = '+octo (GitHub)',
          o = { [[<cmd>Octo actions<cr>]], 'Pick an action' },
          i = { [[<cmd>Octo issue search<cr>]], 'Search issues' },
          p = { [[<cmd>Octo pr search<cr>]], 'Search issues' },
        },
      },
    }
  end,
}
