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

