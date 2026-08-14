return {
  'lewis6991/gitsigns.nvim',
  cond = require('ucw.targets').is_full_ui,
  dependencies = { 'nvim-lua/plenary.nvim' },
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
