local map = require('ucw.utils').map
local actions = require('ucw.keys.actions')

vim.g.mapleader = ' '

local opts = { noremap = true, silent = true }

-- swap 0 to ^
map('n', '0', '^', { noremap = true, silent = true, desc = 'Go to first non-blank character' })
map('n', '^', '0', { noremap = true, silent = true, desc = 'Go to start of line' })

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
map('n', 'p', 'mpp[`', { noremap = true, silent = true, desc = 'Paste after cursor, keep cursor put' })

-- <c-s> as an extra way to exit insert mode and save.
--
-- The `desc` on each is not decoration: which-key falls back to *displaying
-- the rhs* for a mapping that has none, so the visual-mode popup used to
-- carry a literal `<Esc><Cmd>w<CR>` row. Same reason every other mapping in
-- this file grew one - see `ucw.plugins.which-key`'s label block.
map('n', '<c-s>', '<cmd>w<cr>', { desc = 'Write file' })
map('i', '<c-s>', '<esc><cmd>w<cr>', { desc = 'Write file' })
map('v', '<c-s>', '<esc><cmd>w<cr>', { desc = 'Write file' })

-- clear things. This is the only binding of `ucw.keys.actions.clear`, and a
-- grep for `clear()` does not find it - which is how the Phase 5 acceptance
-- review first concluded the function was dead (R3). Hence the desc.
vim.keymap.set('n', '<esc>', actions.clear, { silent = true, desc = 'Clear search highlight and notifications' })

-- jk move over visual lines, but over physical lines when used with a count
vim.keymap.set('n', 'j', function()
  return vim.v.count > 0 and 'j' or 'gj'
end, { expr = true, silent = true, desc = 'Down (visual line, or physical with a count)' })
vim.keymap.set('n', 'k', function()
  return vim.v.count > 0 and 'k' or 'gk'
end, { expr = true, silent = true, desc = 'Up (visual line, or physical with a count)' })

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
  map('n', '<c-/>', 'gcc', { noremap = false, desc = 'Toggle comment on this line' })
else
  -- this is actually Ctrl + /, but in a terminal nvim sees it as <c-_>
  map('n', '<c-_>', 'gcc', { noremap = false, desc = 'Toggle comment on this line' })
end

-- No quickfix pair here: Neovim's own `[q`/`]q` (and `[Q`/`]Q`,
-- `[<C-Q>`/`]<C-Q>`) are a strict superset of the `<cmd>cnext<cr>` pair this
-- file used to bind: they take a count (`3]q`) and print a failure as a plain
-- error message rather than through the Lua error path (Phase 9.5, T6).

-- For mouse. The side buttons are the jumplist, the same pair a browser puts
-- them on.
map({ 'n', 'i', 'v' }, '<X2Mouse>', '<c-i>', { noremap = true, silent = true, desc = 'Jump forward (jumplist)' })
map({ 'n', 'i', 'v' }, '<X1Mouse>', '<c-o>', { noremap = true, silent = true, desc = 'Jump back (jumplist)' })

-- Shift is one notch coarser on the same list: `<C-o>`/`<C-i>` step through
-- every entry, and a handful of edits in one file put a dozen of them there, so
-- "back to where I was before this file" is the native key pressed until the
-- name changes. These do that in one press, and take a count in files
-- (`3<C-S-o>`). `ucw.keys.actions.jump_file` still jumps by handing
-- `{steps}<C-o>` to Neovim, so the jumplist stays Neovim's to maintain.
--
-- Terminal prerequisite, the same one `<C-i>` itself has (Phase 9, D6): Ctrl
-- and Ctrl+Shift are one byte to a terminal unless it speaks CSI-u. tmux is
-- configured for it; Konsole gets there through the user's keytab, which needs
-- an entry per key. Nothing here breaks without them - the keys simply arrive
-- as `<C-o>`/`<C-i>` and do the fine-grained jump.
--
-- Normal mode only, unlike the mouse pair above: `jump_file` runs `normal!`,
-- which has no meaning from insert mode, and `<C-o>` there is Neovim's own
-- one-shot normal command.
vim.keymap.set('n', '<C-S-o>', function()
  actions.jump_file(-1)
end, { silent = true, desc = 'Jump back to the previous file (jumplist)' })
vim.keymap.set('n', '<C-S-i>', function()
  actions.jump_file(1)
end, { silent = true, desc = 'Jump forward to the next file (jumplist)' })
vim.keymap.set('n', '<S-X1Mouse>', function()
  actions.jump_file(-1)
end, { silent = true, desc = 'Jump back to the previous file (jumplist)' })
vim.keymap.set('n', '<S-X2Mouse>', function()
  actions.jump_file(1)
end, { silent = true, desc = 'Jump forward to the next file (jumplist)' })

-- term navigation
map('t', '<esc><esc>', [[<c-\><c-n>]], { noremap = true, silent = true, desc = 'Leave terminal mode' })
