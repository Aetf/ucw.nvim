local au = require('au')
local utils = require('ucw.utils')

-- UI elements
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Color and themes
-- always use 24bits true color
vim.opt.termguicolors = true
-- do not show --INSERT-- because we have statusline
vim.opt.showmode = false
-- show (partial) cmd in status line
vim.opt.showcmd = true

-- Editing
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
vim.opt.textwidth = 120
-- soft wrap at word boundary
vim.opt.wrap = false
vim.opt.linebreak = true

-- show tabs, trailing space and nbsp
vim.opt.list = true
vim.opt.listchars = 'tab:  ⇥,trail:␣,nbsp:☠'

-- folding
-- show a column of fold marker
vim.opt.foldcolumn = '1'
-- fold level higher than this will be closed by default
vim.opt.foldlevel = 1
-- minimum lines to fold
vim.opt.foldminlines = 3
-- unfolds the line in which the cursor is located when opening a file
au.group('OpenFoldOnEnter', {
  {
    'BufWinEnter', '*',
    function()
      vim.cmd [[normal! zv]]
    end
  }
})
-- disable folding while in insert mode, to avoid sudden jumps
au.group('InsertNoFold', {
  {
    'InsertEnter', '*',
    function()
      vim.w.oldfdm = vim.wo.foldmethod
      vim.wo.foldmethod = 'manual'
    end
  },
  {
    'InsertLeave', '*',
    function()
      if vim.w.oldfdm then
        vim.wo.foldmethod = vim.w.oldfdm
      end
      vim.cmd [[normal! zv]]
    end
  },
})

-- live command preview
vim.opt.inccommand = 'split'

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

-- more info to save in session
vim.opt.sessionoptions:append('winpos,terminal')
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
vim.fn.sign_define("DiagnosticSignError", {text = "", texthl = "DiagnosticSignError"})
vim.fn.sign_define("DiagnosticSignWarn", {text = "", texthl = "DiagnosticSignWarn"})
vim.fn.sign_define("DiagnosticSignInfo", {text = "", texthl = "DiagnosticSignInfo"})
vim.fn.sign_define("DiagnosticSignHint", {text = "", texthl = "DiagnosticSignHint"})
vim.diagnostic.config {
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
  -- display higher severity signs over lower ones
  severity_sort = true,
}

-- Terminal related settings
-- disable various gutters for term
au.TermOpen = function()
  vim.opt_local.signcolumn = 'no'
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.foldcolumn = '0'
  -- BufEnter not emitted when initially open term, for some reason
  vim.cmd [[startinsert]]
end

-- start in term mode automatically
au.BufEnter = {
  'term://*',
  function()
    vim.cmd [[startinsert]]
  end
}
