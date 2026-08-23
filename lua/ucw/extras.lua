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
-- `:checktime` runs. Two things run it by themselves - entering a buffer, and
-- a terminal focus event (core does that one, no config involved) - so what
-- is left uncovered is a buffer you are sitting in, in a focused window,
-- while a formatter or a `git checkout` rewrites the file. Measured before
-- this existed: the buffer still showed the old text minutes later.
--
-- (The focus path was dead here for another reason entirely: tmux's
-- `focus-events` was set without a value, which tmux reads as *off*, so
-- Konsole's focus reporting stopped at tmux. Fixed in the tmux config; this
-- autocmd is not a workaround for it.)
--
-- `CursorHold` is the idle hook, not a delay standing in for an event: nvim
-- has no "file changed" notification to hook (`FileChangedShell` fires *from*
-- the check), so the check has to be scheduled, and 'updatetime' (300ms here)
-- is the interval the editor already uses for that.
--
-- Not in the embedded targets, the same call `conform.lua`'s `format_on_save`
-- makes and for the same reason: a reload rewrites the buffer's text, and
-- neither host is a place for this config to do that unasked. vscode-neovim
-- mirrors documents VSCode itself owns and reloads; firenvim's buffers are a
-- browser textarea, where there is no file to be out of date with.
--
-- Unsaved work is never at risk, and that is measured rather than assumed: with
-- the buffer modified, `:checktime` raises the W12 prompt and does not reload,
-- and `FileChangedShellPost` never fires. The `mode()`/`getcmdwintype()` guard
-- is the known crash-shaped case: running it from the command-line window
-- raises E11.
if require('ucw.targets').is_full_ui() then
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

  -- Say so when the reload happened. 'autoread' is silent, which makes a
  -- buffer changing under the cursor look like nvim losing an edit rather
  -- than picking one up.
  --
  -- `FileChangedShellPost` also fires for a file that was *deleted* outside
  -- nvim, where nothing was reloaded and the buffer still holds the only copy
  -- - saying "reloaded" there is simply false, and nvim has already said the
  -- true thing (`E211: File ... no longer available`). Measured: `v:fcs_reason`
  -- is `deleted` in that case and empty on a real reload; the conflict case
  -- does not reach this event at all.
  au.group('AutoReadNotify', {
    {
      'FileChangedShellPost',
      '*',
      function()
        if vim.v.fcs_reason == 'deleted' then
          return
        end
        vim.notify('Reloaded from disk (changed externally)', vim.log.levels.INFO)
      end,
    },
  })
end
