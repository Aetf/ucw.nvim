local map = require('ucw.utils').map
local actions = require('ucw.keys.actions')

vim.g.mapleader = ' '

local opts = { noremap = true, silent = true }

-- swap 0 to ^
map('n', '0', '^', opts) -- go to the first non-blank character of a line
map('n', '^', '0', opts) -- just in case you need to go to the very beginning of a line

-- swap <C-r> and <C-r><C-o>, to paste literally without autoindent
map('i', '<c-r>', '<c-r><c-o>', opts)
map('i', '<c-r><c-o>', '<c-r>', opts)

-- When paste, cursor stays (by jump back to mark p). See :h [`
-- Note that there are p, P, gp, gP
-- Example line `a|b|c`, register content `123`, (| | marks cursor position)
-- p   a|b|123c
-- gP   a123|b|c
-- P   a12|3|bc
-- gp   ab123|c|
-- So p and gP is symmetrical
map('n', 'p', 'mpp[`', opts)

-- <c-s> as an extra way to exit insert mode and save
map('n', '<c-s>', '<cmd>w<cr>')
map('i', '<c-s>', '<esc><cmd>w<cr>')
map('v', '<c-s>', '<esc><cmd>w<cr>')

-- clear things. This is the only binding of `ucw.keys.actions.clear`, and a
-- grep for `clear()` does not find it - which is how the Phase 5 acceptance
-- review first concluded the function was dead (R3). Hence the desc.
vim.keymap.set('n', '<esc>', actions.clear, { silent = true, desc = 'Clear search highlight and notifications' })

-- jk move over visual lines, but over physical lines when used with a count
vim.keymap.set('n', 'j', function()
  return vim.v.count > 0 and 'j' or 'gj'
end, { expr = true, silent = true })
vim.keymap.set('n', 'k', function()
  return vim.v.count > 0 and 'k' or 'gk'
end, { expr = true, silent = true })

-- `gS`/`gE` (jump to start/end of a text object) are gone (Phase 9, D1):
-- `gE` shadowed the native backward-WORD-end motion, and the `[al`-family
-- jumps in `mini.lua` cover the same ground without shadowing anything.

-- folding and lsp
vim.keymap.set('n', 'K', actions.hoverK, { desc = 'Hover over symbol', silent = true })

-- Commenting is Neovim's own since 0.10: `gc` (operator + textobject) and `gcc`
-- (line, honours a count), with 'commentstring' resolved through treesitter
-- including injected languages. That is exactly what Comment.nvim +
-- nvim-ts-context-commentstring provided here, so both were dropped in Phase 4;
-- all that needs config is the editor-style shortcut for the common case.
if require('ucw.utils').is_gui() then
  map('n', '<c-/>', 'gcc', { noremap = false })
else
  -- this is actually Ctrl + /, but in a terminal nvim sees it as <c-_>
  map('n', '<c-_>', 'gcc', { noremap = false })
end

-- common pairs
vim.keymap.set('n', ']q', [[<cmd>cnext<cr>]])
vim.keymap.set('n', '[q', [[<cmd>cprevious<cr>]])

-- For mouse
map({ 'n', 'i', 'v' }, '<X2Mouse>', '<c-i>', opts)
map({ 'n', 'i', 'v' }, '<X1Mouse>', '<c-o>', opts)

-- term navigation
map('t', '<esc><esc>', [[<c-\><c-n>]], opts)
