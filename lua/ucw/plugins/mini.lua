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

      -- mini.ai's own goto keys, kept (Phase 9.5, T6). They mean *left /
      -- right edge of a textobject*, not previous / next - so they belong on
      -- `g`, and the `[`/`]` prefix stays free for the one thing it means
      -- everywhere else in this config: previous / next in some sequence.
      -- What used to be here instead was `[al`/`]al`/`[an`/`]an`/`[il`/`]il`/
      -- `[in`/`]in`, a hand-rolled rebuild of these two that spent the bracket
      -- prefix on the edge and squeezed direction into a third character, and
      -- it forced the diagnostic pair onto `g[`/`g]`. Cost of going back to
      -- upstream: no explicit "previous/next object" selection - `search_method`
      -- below picks the object and a count reaches further ones.
      goto_left = 'g[',
      goto_right = 'g]',
    },

    custom_textobjects = {
      -- ipython cells, they are separated by `# %%` lines
      h = require('ucw.textobjects.ipython').cell,
      H = require('ucw.textobjects.ipython').cell,
      -- treesitter textobjects
      F = ts_spec { a = '@function.outer', i = '@function.inner' },
      B = ts_spec { a = '@block.outer', i = '@block.inner' },
      C = ts_spec { a = '@class.outer', i = '@class.inner' },
    },

    -- Number of lines within which textobject is searched
    n_lines = 50,

    -- How to search for object (first inside current line, then inside
    -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
    -- 'cover_or_nearest', 'next', 'previous', 'nearest'.
    search_method = 'cover_or_next',
  }
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
    },
  }
end

local function setup_icons()
  require('mini.icons').setup {}
  -- Needed by neotree, codediff, octo, bufferline, snacks.picker, lualine
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
