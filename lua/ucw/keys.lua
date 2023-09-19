local map = require('ucw.utils').map
local actions = require('ucw.keys.actions')

vim.g.mapleader = " "

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

-- clear things
vim.keymap.set('n', '<esc>', actions.clear, { silent = true })

-- jk move over visual lines, but over physical lines when used with a count
vim.keymap.set('n', 'j', function()
  return vim.v.count > 0 and 'j' or 'gj'
end, { expr = true, silent = true })
vim.keymap.set('n', 'k', function()
  return vim.v.count > 0 and 'k' or 'gk'
end, { expr = true, silent = true })

-- jump to start/end of a text object
map('n', 'gS', [[<cmd>set opfunc=v:lua.require'ucw.keys.actions'.opfunc_textobj_go_start<cr>g@]], opts)
map('n', 'gE', [[<cmd>set opfunc=v:lua.require'ucw.keys.actions'.opfunc_textobj_go_end<cr>g@]], opts)

-- folding and lsp
vim.keymap.set('n', 'K', actions.hoverK, { desc = "Hover over symbol", silent = true })

-- common pairs
vim.keymap.set('n', ']q', [[<cmd>cnext<cr>]])
vim.keymap.set('n', '[q', [[<cmd>cprevious<cr>]])

-- For mouse
map({'n', 'i', 'v'}, '<X2Mouse>', '<c-i>', opts)
map({'n', 'i', 'v'}, '<X1Mouse>', '<c-o>', opts)

-- term navigation
map('t', '<esc><esc>', [[<c-\><c-n>]], opts)
