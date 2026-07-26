return {
  'akinsho/toggleterm.nvim',
  lazy = false,
  config = function()
    require('toggleterm').setup {
      -- <c-`> requires special config in konsole keytab file:
      -- key `-Shift+Ctrl : "\E[96;5u"
      open_mapping = [[<c-`>]],
      insert_mappings = true,
      terminal_mappings = true,
      hide_numbers = true,
      direction = 'float',
    }
  end,
}
