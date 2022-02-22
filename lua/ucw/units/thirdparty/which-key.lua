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
    ['<M-Enter>'] = { [[<cmd>Telescope lsp_code_actions<cr>]], "Code actions" },
    ['<M-S-Enter>'] = { [[<cmd>Telescope lsp_range_code_actions<cr>]], "Range code actions" },
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
      a = { [[<cmd>Telescope lsp_code_actions<cr>]], "Code actions" },
      A = { [[<cmd>Telescope lsp_range_code_actions<cr>]], "Range code actions" },
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
    ['<leader>g'] = { [[<cmd>Neogit<cr>]], "Neogit" },
  }

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
      b = { [[<cmd>Telescope buffers<cr>]], "Go to buffer" },
    },
    ['<Tab>'] = { [[<cmd>BufferLineCycleNext<cr>]], "Go to next buffer" },
    ['<S-Tab>'] = { [[<cmd>BufferLineCyclePrev<cr>]], "Go to previous buffer" },

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
end

return M
