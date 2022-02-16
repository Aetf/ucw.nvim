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

-- For mouse
map({'n', 'i', 'v'}, '<X2Mouse>', '<c-i>', opts)
map({'n', 'i', 'v'}, '<X1Mouse>', '<c-o>', opts)

-- Code navigation shortcuts
map('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
map('n', '<c-k>', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)

-- Goto prev/next diag warning/error
map('n', 'g[', '<cmd>lua vim.diagnostic.goto_prev()<cr>', opts)
map('n', 'g]', '<cmd>lua vim.diagnostic.goto_next()<cr>', opts)

-- Trouble
map('n', '<leader>xx', '<cmd>TroubleToggle<cr>', opts)
map('n', '<leader>xw', '<cmd>TroubleToggle workspace_diagnostics<cr>', opts)
map('n', '<leader>xd', '<cmd>TroubleToggle document_diagnostics<cr>', opts)
map('n', '<leader>xq', '<cmd>TroubleToggle quickfix<cr>', opts)
map('n', '<leader>xl', '<cmd>TroubleToggle loclist<cr>', opts)
