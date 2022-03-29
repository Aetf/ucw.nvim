local map = require('ucw.utils').map

vim.g.mapleader = " "

local opts = { noremap = true, silent = true }

-- swap 0 to ^
map('n', '0', '^', opts) -- go to the first non-blank character of a line
map('n', '^', '0', opts) -- just in case you need to go to the very beginning of a line

-- swap <C-r> and <C-r><C-o>, to paste literally without autoindent
map('i', '<c-r>', '<c-r><c-o>', opts)
map('i', '<c-r><c-o>', '<c-r>', opts)

-- jk move over visual lines
map('n', 'j', 'gj', opts)
map('n', 'k', 'gk', opts)

-- jump to start/end of a text object
map('n', 'gS', [[<cmd>set opfunc=v:lua.require'ucw.keys.actions'.opfunc_textobj_go_start<cr>g@]], opts)
map('n', 'gE', [[<cmd>set opfunc=v:lua.require'ucw.keys.actions'.opfunc_textobj_go_end<cr>g@]], opts)

-- For mouse
map({'n', 'i', 'v'}, '<X2Mouse>', '<c-i>', opts)
map({'n', 'i', 'v'}, '<X1Mouse>', '<c-o>', opts)

-- Code navigation shortcuts
map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
map('n', '<c-k>', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)

-- term navigation
map('t', '<esc><esc>', [[<c-\><c-n>]], opts)
