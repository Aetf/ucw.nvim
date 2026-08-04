-- echasnovski/mini.nvim submodules all live on the same plugin, so their
-- setups are consolidated into one spec/config here rather than split across
-- files - splitting across top-level specs for the same plugin url would
-- mean lazy.nvim's spec-merge keeps only the last `config` function, not all
-- of them.

local function setup_ai()
  local ts_spec = require('mini.ai').gen_spec.treesitter
  require('mini.ai').setup {
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
  local gen_action = function(seq)
    local edge = ({ ['['] = 'left', [']'] = 'right' })[seq:sub(1, 1)]
    local ai_type = seq:sub(2, 2)
    local prev_next = ({ l = 'prev', n = 'next' })[seq:sub(3, 3)]
    vim.keymap.set({ "n", "v" }, seq,
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

local function setup_surround()
  -- Has builtins for brackets, function call, tag, user prompt, and any alphanumeric/punctuation/whitespace character.
  require('mini.surround').setup {
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

local function setup_move()
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

local function setup_icons()
  require('mini.icons').setup {}
  -- Needed by neotree, diffview, octo, bufferline, snacks.picker, lualine
  MiniIcons.mock_nvim_web_devicons()
  -- Icons for `vim.lsp.protocol.CompletionItemKind`, used by the LSP symbol
  -- pickers. Lives here rather than in `ucw.lsp` because it is icon setup, not
  -- LSP setup - and doing it eagerly puts it in place before any client can
  -- attach, instead of depending on when LSP happens to come up.
  MiniIcons.tweak_lsp_kind()
end

return {
  'echasnovski/mini.nvim',
  lazy = false,
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  config = function()
    setup_icons()
    setup_ai()
    setup_surround()
    setup_move()
  end,
}
