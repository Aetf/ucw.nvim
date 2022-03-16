local M = {}

M.url = 'folke/which-key.nvim'
M.description = [[A helpful reminder about which key to press]]

M.activation = {
  wanted_by = {
    'target.mapping',
  }
}

function M.config()
  local wk = require('which-key')
  wk.setup {
    plugins = {
      presets = {
        operators = false,
        motions = false,
      },
    }
  }
  -- Open Telescope pickers
  wk.register {
    ['<leader>t'] = {
      name = '+telescope',
      h = { [[<cmd>Telescope command_history<cr>]], "Command history" },
      r = { [[<cmd>Telescope reloader<cr>]], "Reload modules" },
    },
    ['<C-p>'] = { [[<cmd>Telescope find_files<cr>]], "Find File" },
    ['<M-S-f>'] = { [[<cmd>Telescope live_grep<cr>]], "Find in CWD" },
    ['<M-f>'] = { [[<cmd>Telescope current_buffer_fuzzy_find<cr>]], "Find in File" },
  }
  -- LSP
  wk.register {
    ['<M-Enter>'] = { [[<cmd>lua vim.lsp.buf.code_action()<cr>]], "Code actions" },
    ['<M-S-Enter>'] = { [[<cmd>lua vim.lsp.buf.range_code_action()<cr>]], "Range code actions" },
    g = {
      ['0'] = { [[<cmd>Telescope lsp_document_symbols<cr>]], "Symbols in the current buffer"},
      W = { [[<cmd>Telescope lsp_workspace_symbols<cr>]], "Symbols in the current workspace"},
      e = { [[<cmd>Telescope diagnostics<cr>]], "Diagnostics for current buffer"},
      D = { [[<cmd>Telescope lsp_implementations<cr>]], "Go to implementation"},
      d = { [[<cmd>Telescope lsp_definitions<cr>]], "Go to definition"},
      t = { [[<cmd>Telescope lsp_type_definitions<cr>]], "Go to type definition"},
      r = { [[<cmd>Telescope lsp_references<cr>]], "Find references"},
    },
    ['<M-S-r>'] = { [[<cmd>lua vim.lsp.buf.rename()<cr>]], "Rename the symbol under cursor" },
  }
  wk.register {
    ['<leader>l'] = {
      name = '+LSP',
      a = { [[<cmd>lua vim.lsp.buf.code_action()<cr>]], "Code actions" },
      A = { [[<cmd>lua vim.lsp.buf.range_code_action()<cr>]], "Range code actions" },
      ['0'] = { [[<cmd>Telescope lsp_document_symbols<cr>]], "Symbols in the current buffer"},
      W = { [[<cmd>Telescope lsp_workspace_symbols<cr>]], "Symbols in the current workspace"},
      e = { [[<cmd>Telescope diagnostics<cr>]], "Diagnostics for current buffer"},
      D = { [[<cmd>Telescope lsp_implementations<cr>]], "Go to implementation"},
      d = { [[<cmd>Telescope lsp_definitions<cr>]], "Go to definition"},
      t = { [[<cmd>Telescope lsp_type_definitions<cr>]], "Go to type definition"},
      r = { [[<cmd>Telescope lsp_references<cr>]], "Find references"},
      h = { [[<cmd>lua vim.lsp.buf.document_highlight()<cr>]], "Highlight symbol under cursor" },
      ['<C-L>'] = { [[<cmd>lua vim.lsp.buf.clear_references()<cr>]], "Clear document highlights from current buffer" },
      f = { [[<cmd>lua vim.lsp.buf.formatting()<cr>]], "Format the current buffer" },
      R = { [[<cmd>lua vim.lsp.buf.rename()<cr>]], "Rename the symbol under cursor" },
    }
  }

  -- Goto prev/next diag warning/error
  wk.register {
    g = {
      ['['] = { [[<cmd>lua require('ucw.keys.actions').diag_prev()<cr>]], "Go to previous diagnostic" },
      [']'] = { [[<cmd>lua require('ucw.keys.actions').diag_next()<cr>]], "Go to next diagnostic" },
    },
  }

  -- Trouble
  wk.register {
    ['<leader>x'] = {
      name = '+trouble',
      x = { [[<cmd>TroubleToggle<cr>]], "Toggle trouble list" },
      w = { [[<cmd>TroubleToggle<cr>]], "Toggle trouble list (workspace)" },
      d = { [[<cmd>TroubleToggle<cr>]], "Toggle trouble list (document)" },
      q = { [[<cmd>TroubleToggle<cr>]], "Toggle trouble list (quickfix)" },
      l = { [[<cmd>TroubleToggle<cr>]], "Toggle trouble list (loclist)" },
    },
  }

  -- Git
  wk.register {
    ['<leader>g'] = {
      name = "+git",
      g = { [[<cmd>Neogit<cr>]], "Neogit" },
    },
    -- hunk navigation
    [']c'] = { [[&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>']], "Next hunk", expr = true },
    ['[c'] = { [[&diff ? ']c' : '<cmd>Gitsigns prev_hunk<CR>']], "Prev hunk", expr = true },
  }
  -- gitsigns
  wk.register {
    ['<leader>g'] = {
      s = { '<cmd>Gitsigns stage_hunk<CR>', "Stage hunk", mode = 'n' },
      r = { '<cmd>Gitsigns reset_hunk<CR>', "Reset hunk", mode = 'n' },
      S = { '<cmd>Gitsigns stage_buffer<CR>', "Stage buffer", mode = 'n' },
      u = { '<cmd>Gitsigns undo_stage_hunk<CR>', "Undo stage hunk", mode = 'n' },
      R = { '<cmd>Gitsigns reset_buffer<CR>', "Reset buffer", mode = 'n' },
      p = { '<cmd>Gitsigns preview_hunk<CR>', "Preview hunk", mode = 'n' },
      b = { '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', "Blame line" },
      d = { '<cmd>Gitsigns diffthis<CR>', "Diff with index", mode = 'n' },
      h = { '<cmd>DiffviewFileHistory<CR>', "History for current buffer", mode = 'n' },
      t = {
        name = "+toggles",
        b = { '<cmd>Gitsigns toggle_current_line_blame<CR>', "Toggle current line blame" },
        d = { '<cmd>Gitsigns toggle_deleted<CR>', "Toggle deleted" },
      }
    },
  }
  wk.register {
    ['<leader>g'] = {
      s = { ':Gitsigns stage_hunk<CR>', "Stage hunk", mode = 'v' },
      r = { ':Gitsigns reset_hunk<CR>', "Reset hunk", mode = 'v' },
    },
  }
  -- text object
  wk.register({
    ['ih'] = { [[:<C-U>Gitsigns select_hunk<CR>]], "Select hunk" },
  }, { mode = 'x' })
  wk.register({
    ['ih'] = { [[:<C-U>Gitsigns select_hunk<CR>]], "Select hunk" },
  }, { mode = 'o' })

  -- Window and Buffer
  wk.register({
    -- for mouse middle button
    ['<C-PageDown>'] = { [[<cmd>BufferLineCycleNext<cr>]], "Go To Next Buffer" },
    ['<C-PageUp>'] = { [[<cmd>BufferLineCyclePrev<cr>]], "Go To Previous Buffer" },
    ['<leader>`'] = { [[<C-^>]], "Go To Alternvative Buffer" },

    ['<leader>s'] = {
      name = "+session",
      s = { [[<cmd>Telescope session-lens search_session<cr>]], "Open session" },
      c = { [[<cmd>SaveSession<cr>]], "Manually save session" },
      r = { [[<cmd>RestoreSession<cr>]], "Manually restore session" },
    },

    ['<leader>t'] = {
      name = '+tab',
      c = { [[<cmd>tabnew<cr>]], "Open new tab page" },
      n = { [[<cmd>tabnext<cr>]], "Go to next tab" },
      p = { [[<cmd>tabprev<cr>]], "Go to previous tab" },
      x = { [[<cmd>tabclose<cr>]], "Close current tab" },
      o = { [[<cmd>tabonly<cr>]], "Close other tabs" },
    },
    ['<M-n>'] = { [[<cmd>lua require('Navigator').tabnext()<cr>]], "Go to next tab" },
    ['<M-p>'] = { [[<cmd>lua require('Navigator').tabprev()<cr>]], "Go to previous tab" },
    ['<M-Bar>'] = { [[<cmd>lua require('Navigator').tablast()<cr>]], "Go to last tab" },

    ['<leader>b'] = {
      name = '+buffer',
      d = { [[<cmd>BufferLinePickClose<cr>]], "Pick Buffer To Close" },
      x = { [[<cmd>lua require('ucw.keys.actions').bufdelete()<cr>]], "Delete current buffer" },
      X = { [[<cmd>lua require('ucw.keys.actions').bufdelete(0, true)<cr>]], "Delete current buffer" },
      b = { [[<cmd>Telescope buffers<cr>]], "Go to buffer" },
    },
    ['<Tab>'] = { [[<cmd>lua require('ucw.keys.actions').bufnext()<cr>]], "Go to next buffer" },
    ['<S-Tab>'] = { [[<cmd>lua require('ucw.keys.actions').bufprev()<cr>]], "Go to previous buffer" },

    ['<leader>w'] = {
      name = '+window',
      x = { [[<C-w>c]], "Close current window" },
      v = { [[<cmd>split<cr>]], "Create new window vertically" },
      h = { [[<cmd>vsplit<cr>]], "Create new window horizontally" },
    },
    ['<M-h>'] = { [[<cmd>lua require('Navigator').left()<cr>]], "Go to left window" },
    ['<M-j>'] = { [[<cmd>lua require('Navigator').down()<cr>]], "Go to down window" },
    ['<M-k>'] = { [[<cmd>lua require('Navigator').up()<cr>]], "Go to up window" },
    ['<M-l>'] = { [[<cmd>lua require('Navigator').right()<cr>]], "Go to right window" },
    ['<M-Bslash>'] = { [[<cmd>lua require('Navigator').previous()<cr>]], "Go to last window" },
  })
  wk.register({
    ['<M-h>'] = { [[<cmd>lua require('Navigator').left()<cr>]], "Go to left window" },
    ['<M-j>'] = { [[<cmd>lua require('Navigator').down()<cr>]], "Go to down window" },
    ['<M-k>'] = { [[<cmd>lua require('Navigator').up()<cr>]], "Go to up window" },
    ['<M-l>'] = { [[<cmd>lua require('Navigator').right()<cr>]], "Go to right window" },
    ['<M-Bslash>'] = { [[<cmd>lua require('Navigator').previous()<cr>]], "Go to last window" },
  }, { mode = 't' })
end

return M
