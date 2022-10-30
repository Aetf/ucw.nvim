local M = {}

M.description = 'mini.ai for extended a/i textobjects'

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

-- Customizable creation of a/i textobjects using Lua patterns and functions. Supports:
-- * Dot-repeat.
-- * v:count.
-- * Different search methods (see help for MiniAi.config).
-- * Consecutive application (update selection without leaving Visual mode).
-- * Aliases for multiple textobjects.
-- Comprehensive builtin textobjects (see more in help for MiniAi-textobject-builtin):
-- * Balanced brackets (with and without whitespace) plus alias.
-- * Balanced quotes plus alias.
-- * Function call.
-- * Argument.
-- * Tag.
-- * Derived from user prompt.
-- * Default for punctuation, digit, or whitespace single character.
-- Motions for jumping to left/right edge of textobject.
-- Set of specification generators to tweak some builtin textobjects (see help for MiniAi.gen_spec).
-- Treesitter textobjects (through MiniAi.gen_spec.treesitter() helper).
function M.setup()
  require('mini.ai').setup{
    mappings = {
      -- Main textobject prefixes
      around = 'a',
      inside = 'i',

      -- Next/last variants
      around_next = 'an',
      inside_next = 'in',
      around_last = 'al',
      inside_last = 'il',

      -- Move cursor to corresponding edge of `a` textobject
      goto_left = 'g[',
      goto_right = 'g]',
    },

    -- Number of lines within which textobject is searched
    n_lines = 50,

    -- How to search for object (first inside current line, then inside
    -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
    -- 'cover_or_nearest', 'next', 'previous', 'nearest'.
    search_method = 'cover_or_next',
  }
end

return M
