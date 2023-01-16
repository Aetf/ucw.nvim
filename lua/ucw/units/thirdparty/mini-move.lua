local M = {}

M.description = 'mini.move for move selections (or current line) in any directions'

M.requires = {
  'mini',
}
M.after = {
  'mini',
}

M.activation = {
  wanted_by = {
    'target.basic',
  }
}

function M.setup()
  require('mini.move').setup {
    -- use Meta-Shift + <jkhl> to move around
    mappings = {
      -- move visual section in visual mode
      left = '<M-H>',
      right = '<M-L>',
      down = '<M-J>',
      up = '<M-K>',
      -- move current line in normal mode
      line_left = '<M-H>',
      line_right = '<M-L>',
      line_down = '<M-J>',
      line_up = '<M-K>',
    }
  }
end

return M
