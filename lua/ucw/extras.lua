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

-- `q` closes the two read-only windows that had no way out but `:q`
-- (Phase 9.5, T7). Everything else this config opens already closes on `q` -
-- measured across lazy, mason, checkhealth, neo-tree, the snacks picker and
-- notification history, noice's split and popup views, every codediff tab,
-- neogit, `man`, and the native LSP hover and gitsigns preview floats - which
-- makes `q` the convention rather than an invention, and these two the
-- outliers. `<Esc>` is deliberately not given the same job: it already means
-- "clear search highlight and dismiss notifications" globally (`ucw.keys`),
-- and it is the *cancel* key in anything that takes typed input.
--
-- `<C-w>q` verbatim from Neovim's own `man` mapping, which is the same idea
-- in the runtime: quit this window, and behave like `:q` when it is the last
-- one. Buffer-local, so `q` keeps recording macros everywhere else.
au.group('CloseWithQ', {
  {
    'FileType',
    { 'help', 'qf' },
    function()
      -- `buffer = 0`, not an event argument: `ucw.au` registers through the
      -- `:autocmd` string form, so the callback takes none. `FileType` fires
      -- with the buffer it is about already current.
      vim.keymap.set('n', 'q', '<C-w>q', {
        buffer = 0,
        silent = true,
        desc = 'Close this window',
      })
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
