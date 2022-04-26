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
    open_mapping = [[<c-`>]], -- <c-`> not working, reported as <c-space>
    open_mapping = [[<c-space>]],
    insert_mappings = true,
    terminal_mappings = true,
    hide_numbers = true,
    direction = 'float',
  }
end

return M
