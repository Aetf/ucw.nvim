return {
  'lewis6991/gitsigns.nvim',
  cond = require('ucw.targets').is_full_ui,
  -- snacks: `config()` builds `Snacks.toggle`s; both specs are eager, but
  -- only `dependencies` guarantees the order
  dependencies = { 'nvim-lua/plenary.nvim', 'folke/snacks.nvim' },
  -- `keys` alone would flip the spec to lazy-loading; the gutter has to exist
  -- from startup, so stay eager (Phase 8 relocates registration, not triggers).
  lazy = false,
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. The `<leader>g`
  -- group header stays there. A side effect of the move, wanted:
  -- in embedded targets (`cond` false) these keys no longer exist at all,
  -- where before they were registered everywhere and bound to ex-commands of
  -- a plugin that never loads there.
  -- `silent = true` on every entry restores what the `wk.add` originals had
  -- (which-key defaults to silent, `vim.keymap.set` does not) - acceptance
  -- review R1: the `:`-prefixed visual/textobject entries would otherwise
  -- type a visible command line.
  --
  -- `[c` used to read `&diff ? ']c' : …` - both hunk motions evaluated to
  -- *next* hunk inside a diff (measured under `diffthis`; upstream's own
  -- README has `[c` on that branch). Same remnant class as iron's `')`,
  -- fixed by the same D4 standard (acceptance review R5).
  keys = {
    {
      '[c',
      "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'",
      desc = 'Prev hunk',
      expr = true,
      replace_keycodes = false,
      silent = true,
    },
    {
      ']c',
      "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'",
      desc = 'Next hunk',
      expr = true,
      replace_keycodes = false,
      silent = true,
    },
    { '<leader>gR', '<cmd>Gitsigns reset_buffer<CR>', desc = 'Reset buffer', silent = true },
    { '<leader>gS', '<cmd>Gitsigns stage_buffer<CR>', desc = 'Stage buffer', silent = true },
    { '<leader>gb', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', desc = 'Blame line', silent = true },
    { '<leader>gd', '<cmd>Gitsigns diffthis<CR>', desc = 'Diff with index', silent = true },
    { '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>', desc = 'Preview hunk', silent = true },
    { '<leader>gr', '<cmd>Gitsigns reset_hunk<CR>', desc = 'Reset hunk', silent = true },
    { '<leader>gs', '<cmd>Gitsigns stage_hunk<CR>', desc = 'Stage hunk', silent = true },
    -- `<leader>ub`/`<leader>ud` (blame/show-deleted toggles) are
    -- `Snacks.toggle`s registered in `config()` below (Phase 8, D2), not
    -- `keys =` entries; they live under the `<leader>u` toggle prefix
    -- (Phase 9, D4) but stay in this file with the plugin that owns them.
    { '<leader>gu', '<cmd>Gitsigns undo_stage_hunk<CR>', desc = 'Undo stage hunk', silent = true },
    { '<leader>gr', ':Gitsigns reset_hunk<CR>', desc = 'Reset hunk', mode = 'v', silent = true },
    { '<leader>gs', ':Gitsigns stage_hunk<CR>', desc = 'Stage hunk', mode = 'v', silent = true },
    { 'ic', ':<C-U>Gitsigns select_hunk<CR>', desc = 'Select hunk (change) ', mode = { 'x', 'o' }, silent = true },
  },
  config = function()
    require('gitsigns').setup()
    -- define some functions as vim commands so they are reachable from the
    -- cmdline, and so from command history and completion
    local function cmd(name, fn)
      vim.api.nvim_create_user_command(name, fn, {})
    end
    cmd('GitsignsStageHunk', function()
      require('gitsigns').stage_hunk()
    end)
    cmd('GitsignsResetHunk', function()
      require('gitsigns').reset_hunk()
    end)
    -- Deprecated in favour of `stage_hunk()` on staged signs, and *not* replaced
    -- here, for the same reason as `toggle_deleted` below: upstream's suggested
    -- replacement is a different operation, not a renamed one.
    --   * `undo_stage_hunk()` pops a session-local LIFO (`bcache.staged_diffs`)
    --     and unstages whatever comes off it. The cursor is never consulted.
    --   * `stage_hunk()` acts on the hunk *at the cursor*, and only inverts when
    --     there is no unstaged hunk there.
    -- Measured in a real TUI on a two-hunk repo: with the cursor on an unstaged
    -- hunk, the "undo" command *stages* it, and between hunks it does nothing
    -- where it used to work. A command called `GitsignsUndoStageHunk` that
    -- sometimes stages is worse than a deprecation warning. Turning this into a
    -- cursor-local toggle is a behaviour decision for whoever wants one - see
    -- docs/design/phase7-ci.md §7 and the acceptance review's R2.
    cmd('GitsignsUndoStageHunk', function()
      ---@diagnostic disable-next-line: deprecated
      require('gitsigns').undo_stage_hunk()
    end)
    cmd('GitsignsPreviewHunk', function()
      require('gitsigns').preview_hunk()
    end)

    cmd('GitsignsStageBuffer', function()
      require('gitsigns').stage_buffer()
    end)
    cmd('GitsignsResetBuffer', function()
      require('gitsigns').reset_buffer()
    end)
    cmd('GitsignsBlameLine', function()
      require('gitsigns').blame_line { full = true }
    end)
    cmd('GitsignsToggleCurrentLineBlame', function()
      require('gitsigns').toggle_current_line_blame()
    end)
    cmd('GitsignsDiffThis', function()
      require('gitsigns').diffthis()
    end)
    cmd('GitsignsDiff', function()
      require('gitsigns').diffthis('~')
    end)
    -- Deprecated in favour of `preview_hunk_inline()`, and *not* replaced here
    -- on purpose: those two are not the same thing. `toggle_deleted` flips the
    -- persistent `show_deleted` config for the buffer; `preview_hunk_inline`
    -- shows the deleted lines of the hunk under the cursor, once. Swapping one
    -- for the other is a behaviour decision, not a lint fix - see
    -- docs/design/phase7-ci.md §7.
    cmd('GitsignsToggleDeleted', function()
      ---@diagnostic disable-next-line: deprecated
      require('gitsigns').toggle_deleted()
    end)

    -- The two gitsigns toggles as `Snacks.toggle`s (Phase 8, D2): state read
    -- from `gitsigns.config`, written through the toggle functions' explicit
    -- `value` parameter - both measured to exist in the pinned gitsigns
    -- (actions.lua:222/:237). Registered here rather than in `keys =` because
    -- a stateful toggle needs the object, not just an rhs; `config()` runs at
    -- startup for this eager spec, so the keys exist at boot the same as the
    -- others.
    Snacks.toggle
      .new({
        id = 'gitsigns_blame',
        name = 'Current line blame',
        get = function()
          return require('gitsigns.config').config.current_line_blame
        end,
        set = function(state)
          require('gitsigns').toggle_current_line_blame(state)
        end,
      })
      :map('<leader>ub', { silent = true })
    Snacks.toggle
      .new({
        id = 'gitsigns_deleted',
        name = 'Show deleted',
        get = function()
          return require('gitsigns.config').config.show_deleted
        end,
        set = function(state)
          -- deprecated upstream, same status and same reasoning as the
          -- `GitsignsToggleDeleted` command right above
          ---@diagnostic disable-next-line: deprecated
          require('gitsigns').toggle_deleted(state)
        end,
      })
      :map('<leader>ud', { silent = true })
  end,
}
