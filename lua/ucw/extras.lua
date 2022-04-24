local au = require('au')

-- Save file with root
vim.cmd [[command! -bar W exe 'w !pkexec tee >/dev/null %:p:S' | setl nomod]]

-- Highlight
au.group('HighlightYank', {
  { 'TextYankPost', '*', function() vim.highlight.on_yank { timeout = 200 } end },
})

-- return to last edit position when opening files (You want this!)
au.group('RestoreLastCursor', {
  {
    'BufReadPost', '*',
    function()
      local pos = vim.api.nvim_buf_get_mark(0, '"')
      if pos[1] > 0 then
        vim.api.nvim_win_set_cursor(0, pos)
      end
    end,
  }
})

-- return to last accessed window when closing current one
au.group('RestoreLastWindow', {
  {
    { 'VimEnter', 'WinEnter' }, '*',
    function()
      -- Exclude floating windows
      if '' ~= vim.api.nvim_win_get_config(0).relative then return end
      -- Record the window we jump from (previous) and to (current)
      if nil == vim.t.winid_rec then
        vim.t.winid_rec = { prev = vim.fn.win_getid(), current = vim.fn.win_getid() }
      else
        vim.t.winid_rec = { prev = vim.t.winid_rec.current, current = vim.fn.win_getid() }
      end

      -- Loop through all windows to check if the previous one has been closed
      for winnr=1,vim.fn.winnr('$') do
        if vim.fn.win_getid(winnr) == vim.t.winid_rec.prev then
          return        -- Return if previous window is not closed
        end
      end

      vim.cmd [[ wincmd p ]]
    end
  }
})
