local M = {}

M.description = 'mini.surround for surround actions'

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

-- Has builtins for brackets, function call, tag, user prompt, and any alphanumeric/punctuation/whitespace character.
function M.setup()
  require('mini.surround').setup{
    -- similar to 'tpope/vim-surround' keymap, disable not used keymaps
    mappings = {
      add = 'ys',
      delete = 'ds',
      replace = 'cs',
      find = '',
      find_left = '',
      highlight = '',
      update_n_lines = '',
    },
    search_method = 'cover_or_next',
  }
end

return M
