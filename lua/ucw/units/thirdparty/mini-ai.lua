local M = {}

M.description = 'mini.ai for extended a/i textobjects'

M.requires = {
  'mini',
}
M.after = {
  'mini',
}
M.wants = {
  'ts-textobjects',
}

M.activation = {
  wanted_by = {
    'target.basic',
  }
}

-- Enabled text objects:
-- * Balanced brackets (with and without whitespace) plus alias ('b' for any brackets).
-- * Balanced quotes plus alias ('q' for any quote).
-- * Function call ('f').
-- * Argument ('a').
-- * Tag ('t').
-- * Derived from user prompt ('?').
-- * Default for punctuation, digit, or whitespace single character.
-- * TS textobjects
--   + Function ('F')
--   + Block ('B')
--   + Class ('C')
-- * IPython cell ('h', 'H')
--
-- Motions for jumping to left/right edge of textobject ('g]' and 'g[')
function M.setup()
  local ts_spec = require('mini.ai').gen_spec.treesitter
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

      -- will define our own
      goto_left = '',
      goto_right = '',
    },

    custom_textobjects = {
      -- ipython cells, they are separated by `# %%` lines
      h = require('ucw.textobjects.ipython').cell,
      H = require('ucw.textobjects.ipython').cell,
      -- treesitter textobjects
      F = ts_spec({ a = '@function.outer', i = '@function.inner' }),
      B = ts_spec({ a = '@block.outer', i = '@block.inner' }),
      C = ts_spec({ a = '@class.outer', i = '@class.inner' }),
    },

    -- Number of lines within which textobject is searched
    n_lines = 50,

    -- How to search for object (first inside current line, then inside
    -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
    -- 'cover_or_nearest', 'next', 'previous', 'nearest'.
    search_method = 'cover_or_next',
  }

  -- Move cursor to corresponding edge of `a` textobject
  local jump_textobject = require('ucw.keys.actions').jump_textobject
  local gen_action = function(seq)
    local edge = ({ ['['] = 'left', [']'] = 'right' })[seq:sub(1, 1)]
    local ai_type = seq:sub(2, 2)
    local prev_next = ({ l = 'prev', n = 'next' })[seq:sub(3, 3)]
    vim.keymap.set({"n", "v"}, seq,
      function()
        return string.format([[<Cmd>lua UCW.jump_textobject('%s', '%s', '%s')<CR>]], prev_next, edge, ai_type)
      end,
      {
        expr = true,
        desc = string.format('Jump to %s edge of %s `%s` text object', edge, ai_type, prev_next)
      }
    )
  end
  gen_action('[al')
  gen_action(']al')
  gen_action('[an')
  gen_action(']an')
  gen_action('[in')
  gen_action(']in')
  gen_action('[il')
  gen_action(']il')
end

return M
