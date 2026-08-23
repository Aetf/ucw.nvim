local au = require('au')

-- Save file with root
vim.cmd([[command! -bar W exe 'w !pkexec tee >/dev/null %:p:S' | setl nomod]])

-- Highlight
au.group('HighlightYank', {
  {
    'TextYankPost',
    '*',
    function()
      vim.highlight.on_yank { timeout = 200 }
    end,
  },
})

-- return to last edit position when opening files (You want this!)
au.group('RestoreLastCursor', {
  {
    'BufReadPost',
    '*',
    function()
      local pos = vim.api.nvim_buf_get_mark(0, '"')
      if pos[1] > 0 then
        -- this may fail if the buffer is shorter than pos, just ignore that
        pcall(vim.api.nvim_win_set_cursor, 0, pos)
      end
    end,
  },
})

-- return to last accessed window when closing current one
au.group('RestoreLastWindow', {
  {
    { 'VimEnter', 'WinEnter' },
    '*',
    function()
      -- Exclude floating windows
      if '' ~= vim.api.nvim_win_get_config(0).relative then
        return
      end
      -- Record the window we jump from (previous) and to (current)
      if nil == vim.t.winid_rec then
        vim.t.winid_rec = { prev = vim.fn.win_getid(), current = vim.fn.win_getid() }
      else
        vim.t.winid_rec = { prev = vim.t.winid_rec.current, current = vim.fn.win_getid() }
      end

      -- Loop through all windows to check if the previous one has been closed
      for winnr = 1, vim.fn.winnr('$') do
        if vim.fn.win_getid(winnr) == vim.t.winid_rec.prev then
          return -- Return if previous window is not closed
        end
      end

      vim.cmd([[ wincmd p ]])
    end,
  },
})

-- The other half of 'autoread' (see `ucw.options`): the option only says what
-- to do when nvim notices a file changed on disk, and nvim only looks when
-- `:checktime` runs. In a terminal that is buffer-entry, `:!cmd`, and focus
-- events - so a file rewritten by a formatter, a `git checkout`, or the other
-- half of a split tmux session goes unnoticed for as long as the cursor stays
-- put. Measured before this existed: an externally rewritten buffer still
-- showed the old text minutes later.
--
-- `CursorHold` is the idle hook, not a delay standing in for an event: nvim
-- has no "file changed" notification to hook (`FileChangedShell` fires *from*
-- the check), so the check has to be scheduled, and 'updatetime' (300ms here)
-- is the interval the editor already uses for that.
--
-- `:checktime` is a no-op for a modified buffer - it sets the "changed on
-- disk" flag and prompts instead of overwriting - so unsaved work is never at
-- risk. The `mode()`/`getcmdwintype()` guard is the known crash-shaped case:
-- running it from the command-line window raises E11.
au.group('AutoReadChanged', {
  {
    { 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI', 'TermLeave' },
    '*',
    function()
      if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
        vim.cmd('checktime')
      end
    end,
  },
})

-- Say so when the reload actually happened. 'autoread' is silent, which makes
-- a buffer changing under the cursor look like nvim losing the edit.
au.group('AutoReadNotify', {
  {
    'FileChangedShellPost',
    '*',
    function()
      vim.notify('Reloaded from disk (changed externally)', vim.log.levels.INFO)
    end,
  },
})
