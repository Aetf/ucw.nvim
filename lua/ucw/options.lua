local au = require('au')
local utils = require('ucw.utils')
local targets = require('ucw.targets')

-- UI elements
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Color and themes
-- always use 24bits true color
vim.opt.termguicolors = true
-- less chatty
-- do not show --INSERT--
vim.opt.showmode = false
-- do not show search reached bottom/top
vim.opt.shortmess:append('s')
-- do not show ruler message, which spams the message log
vim.opt.ruler = false
-- show (partial) cmd in status line
vim.opt.showcmd = true

-- Editing
-- mouse
vim.opt.mouse = 'nvi'
vim.opt.mousemodel = 'popup'
-- h,l and left/right keys should be able to move across lines
vim.opt.whichwrap:append('h,l,<,>')
-- use spaces instead of tabs
vim.opt.expandtab = true
-- 1 tab == 4 spaces
vim.opt.shiftwidth=4
vim.opt.tabstop=4

-- smart indent (only a fallback when indentexpr is not available, which will be set by treesitter
vim.opt.smartindent = true

-- hard wrap
vim.opt.textwidth = 80
-- soft wrap at word boundary
vim.opt.wrap = false
vim.opt.linebreak = true

-- show tabs, trailing space and nbsp
vim.opt.list = true
vim.opt.listchars = 'tab:  ⇥,trail:␣,nbsp:☠'

-- folding
--
-- Which engine provides folds depends on the context, and this is the only
-- place that branch is stated:
--
--   * full UI (tui/gui) -> nvim-ufo, which owns 'foldmethod', 'foldexpr',
--     'foldlevel' and 'foldtext' itself. See lua/ucw/plugins/ufo.lua.
--   * firenvim/vscode   -> ufo is not loaded (`cond = is_full_ui`), so folds
--     come from Neovim's native treesitter foldexpr, set below.
--
-- Before Phase 4 the second case was served by a `foldmethod`/`foldexpr` pair
-- in treesitter.lua that only ever reached those contexts *because* ufo
-- happened not to load and overwrite it - accident rather than design.
--
-- show a column of fold marker
vim.opt.foldcolumn = '1'
-- minimum lines to fold
vim.opt.foldminlines = 3
if not targets.is_full_ui() then
  vim.opt.foldmethod = 'expr'
  vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  -- These contexts have a cramped layout (a browser textarea, a VSCode editor
  -- pane), so opening files mostly folded is the useful default there. The
  -- full UI gets ufo's `foldlevel = 99` instead, which is a requirement of
  -- ufo's manual-fold model rather than a preference - see ufo.lua.
  vim.opt.foldlevel = 1
end
-- Unfold the line the cursor lands on, when opening a file and when leaving
-- insert mode. Only does anything where 'foldlevel' is low enough for folds to
-- be closed in the first place, i.e. the embedded contexts above.
--
-- This used to be paired with an `InsertEnter` handler that forced
-- `foldmethod=manual` for the duration of insert mode - a real trick for expr
-- folds, but a measured no-op under ufo, which sets `foldmethod=manual` itself
-- and recomputes folds from its own async provider rather than from 'foldexpr'.
-- Removed in Phase 4; see docs/design/phase4-folding-comments.md §1.2.
au.group('UnfoldCursorLine', {
  {
    { 'BufWinEnter', 'InsertLeave' }, '*',
    function()
      vim.cmd [[normal! zv]]
    end
  },
})

-- live command preview
vim.opt.inccommand = 'split'

-- diff mode
-- do a second diff stage to match lines in hunk
vim.opt.diffopt:append('linematch:120')
-- generate minimal diff
vim.opt.diffopt:append('algorithm:histogram')

-- Program beheavior

-- timeout in ms to wait for a mapped sequence to complete, also controls which-key
vim.opt.timeoutlen = 500

-- persistent states
vim.opt.undodir = vim.fn.stdpath('data') .. '/undo'
vim.opt.undofile = true
-- persistent state
-- ! - Upper case global variables
-- ' - Number of files to remember marks
-- f - Remember file marks
-- < - Lines of registers
-- h - Disable hlsearch on restore
-- s - Max size per item
-- / - Pattern search history
-- : - Command history
vim.opt.shada = [[!,'1000,<500,s100,h,/100,:100,f1]]

-- more info to save in session (required by auto-session)
vim.opt.sessionoptions:append('winpos,terminal,localoptions')
-- saving options may interference with packer.nvim lazy loading
vim.opt.sessionoptions:remove('options')

-- auto reload externally changed file
vim.opt.autoread = true
-- always reserve 3 lines ahead the cursor - when moving vertically using j/k
vim.opt.scrolloff = 3
-- turn on the WiLd menu
vim.opt.wildmenu = true
vim.opt.wildmode = 'longest'
-- ignore compiled files
vim.opt.wildignore = '*.o,*~,*.pyc,*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store'
-- case insensitive when searching, but be case sensitive when there's upper case characters
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- makes search act like search in modern browsers
vim.opt.incsearch = true
-- show matching brackets when text indicator is over them
vim.opt.showmatch = true
-- how many tenths of a second to blink when matching brackets
vim.opt.matchtime = 2
-- additional encodings to consider
vim.opt.fileencodings = 'ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,default,latin1'
-- window beaheaviors
vim.opt.splitbelow = true
vim.opt.splitright = true

-- LSP related settings
-- always show diagnostics column
vim.opt.signcolumn = 'yes'
-- 300ms of no cursor movement to trigger CursorHold
vim.opt.updatetime = 300
-- signs
vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
    linehl = {
      [vim.diagnostic.severity.ERROR] = "Error",
      [vim.diagnostic.severity.WARN] = "Warn",
      [vim.diagnostic.severity.INFO] = "Info",
      [vim.diagnostic.severity.HINT] = "Hint",
    },
  },
  underline = {
    -- only show for above WARN
    severity = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.ERROR },
  },
  virtual_text = {
    -- only show for above INFO
    severity = { min = vim.diagnostic.severity.INFO, max = vim.diagnostic.severity.ERROR },
    -- show source name if there are multiples
    source = 'if_many',
    prefix = '●',
    --prefix = 'Hahaha:',
  },
  -- Full diagnostic text under the cursor's line only, toggled by `<leader>lp`
  -- (ucw.keys.actions.toggle_virtual_lines).
  --
  -- This used to be lsp_lines.nvim, which replaced core's `virtual_lines`
  -- handler with its own. Core absorbed the same rendering (measured: same
  -- box drawing, same multi-line indentation), so the plugin is gone. Note the
  -- option is `current_line`; lsp_lines called it `only_current_line`.
  --
  -- Off in the embedded contexts, the same branch (and the same reason) as
  -- 'foldlevel' above: a browser textarea or a VSCode editor pane cannot spare
  -- two or three lines under the cursor. lsp_lines was `cond = is_full_ui`, so
  -- this is where that condition went rather than a new restriction.
  virtual_lines = targets.is_full_ui() and { current_line = true } or false,
  -- display higher severity signs over lower ones
  severity_sort = true,
}

