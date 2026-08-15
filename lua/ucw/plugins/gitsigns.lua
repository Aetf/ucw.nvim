return {
  'lewis6991/gitsigns.nvim',
  cond = require('ucw.targets').is_full_ui,
  dependencies = { 'nvim-lua/plenary.nvim' },
  -- `keys` alone would flip the spec to lazy-loading; the gutter has to exist
  -- from startup, so stay eager (Phase 8 relocates registration, not triggers).
  lazy = false,
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. Group headers
  -- (`<leader>g`, `<leader>gt`) stay there. A side effect of the move, wanted:
  -- in embedded targets (`cond` false) these keys no longer exist at all,
  -- where before they were registered everywhere and bound to ex-commands of
  -- a plugin that never loads there.
  keys = {
    { '[c', "&diff ? ']c' : '<cmd>Gitsigns prev_hunk<CR>'", desc = 'Prev hunk', expr = true, replace_keycodes = false },
    { ']c', "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", desc = 'Next hunk', expr = true, replace_keycodes = false },
    { '<leader>gR', '<cmd>Gitsigns reset_buffer<CR>', desc = 'Reset buffer' },
    { '<leader>gS', '<cmd>Gitsigns stage_buffer<CR>', desc = 'Stage buffer' },
    { '<leader>gb', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', desc = 'Blame line' },
    { '<leader>gd', '<cmd>Gitsigns diffthis<CR>', desc = 'Diff with index' },
    { '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>', desc = 'Preview hunk' },
    { '<leader>gr', '<cmd>Gitsigns reset_hunk<CR>', desc = 'Reset hunk' },
    { '<leader>gs', '<cmd>Gitsigns stage_hunk<CR>', desc = 'Stage hunk' },
    { '<leader>gtb', '<cmd>Gitsigns toggle_current_line_blame<CR>', desc = 'Toggle current line blame' },
    { '<leader>gtd', '<cmd>Gitsigns toggle_deleted<CR>', desc = 'Toggle deleted' },
    { '<leader>gu', '<cmd>Gitsigns undo_stage_hunk<CR>', desc = 'Undo stage hunk' },
    { '<leader>gr', ':Gitsigns reset_hunk<CR>', desc = 'Reset hunk', mode = 'v' },
    { '<leader>gs', ':Gitsigns stage_hunk<CR>', desc = 'Stage hunk', mode = 'v' },
    { 'ic', ':<C-U>Gitsigns select_hunk<CR>', desc = 'Select hunk (change) ', mode = { 'x', 'o' } },
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
  end,
}
