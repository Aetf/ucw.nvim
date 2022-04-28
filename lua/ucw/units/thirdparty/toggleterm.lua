local M = {}

M.url = 'akinsho/toggleterm.nvim'
M.description = 'Easily manage multiple terminal windows'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  },
}

function M.config()
  require('toggleterm').setup{
    -- <c-`> requires special config in konsole keytab file:
    -- key `-Shift+Ctrl : "\E[96;5u"
    open_mapping = [[<c-`>]],
    insert_mappings = true,
    terminal_mappings = true,
    hide_numbers = true,
    direction = 'float',
  }
end

return M
