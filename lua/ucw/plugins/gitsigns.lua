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
    -- gitsigns unified staging and unstaging: with staged signs shown,
    -- `stage_hunk()` on an already-staged hunk is what undoes it, and
    -- `undo_stage_hunk()` is deprecated in favour of exactly that. The command
    -- name stays - the point of this list is that these are reachable from the
    -- cmdline and from command history, and that surface should not shift under
    -- the user because upstream merged two functions.
    cmd('GitsignsUndoStageHunk', function()
      require('gitsigns').stage_hunk()
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
