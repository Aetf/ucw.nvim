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
  wk.add {
    { '<leader>T', group = 'telescope' },
    { '<leader>Th', [[<cmd>Telescope command_history<cr>]], desc = "Command history" },
    { '<leader>Tr', [[<cmd>Telescope reloader<cr>]], desc = "Reload modules" },

    {'<C-p>', [[<cmd>Telescope find_files<cr>]], desc = "Find File" },
    {'<M-S-f>', [[<cmd>Telescope live_grep<cr>]], desc = "Find in CWD" },
    {'<M-f>', [[<cmd>Telescope current_buffer_fuzzy_find<cr>]], desc = "Find in File" },
  }
  -- LSP
  wk.add {
    { '<leader>l', group = 'LSP' },
    { '<leader>ll', [[<cmd>lua nvimctl:start 'target.lsp'<cr>]], desc = "Enable LSP"},
    { '<leader>la', [[<cmd>lua vim.lsp.buf.code_action()<cr>]], desc = "Code actions" },
    { '<leader>lA',  [[<cmd>lua vim.lsp.buf.range_code_action()<cr>]], desc = "Range code actions" },
    { '<leader>l0',  [[<cmd>Telescope lsp_document_symbols<cr>]], desc = "Symbols in the current buffer"},
    { '<leader>lW',  [[<cmd>Telescope lsp_workspace_symbols<cr>]], desc = "Symbols in the current workspace"},
    { '<leader>le',  [[<cmd>Telescope diagnostics<cr>]], desc = "Diagnostics for current buffer"},
    { '<leader>lD',  [[<cmd>Telescope lsp_implementations<cr>]], desc = "Go to implementation"},
    { '<leader>ld',  [[<cmd>Telescope lsp_definitions<cr>]], desc = "Go to definition"},
    { '<leader>lt',  [[<cmd>Telescope lsp_type_definitions<cr>]], desc = "Go to type definition"},
    { '<leader>lH',   [[<cmd>lua vim.lsp.declaration()<cr>]], desc = "Go to declaration"},
    { '<leader>lr', [[<cmd>Telescope lsp_references<cr>]], desc = "Find references"  },
    { '<leader>lh',   [[<cmd>lua vim.lsp.buf.document_highlight()<cr>]], desc = "Highlight symbol under cursor" },
    { '<leader>l<C-L>',   [[<cmd>lua vim.lsp.buf.clear_references()<cr>]], desc = "Clear document highlights from current buffer" },
    { '<leader>lf',   [[<cmd>lua vim.lsp.buf.format({ async = false })<cr>]], desc = "Format the current buffer (or visual selection)" },
    { '<leader>lR',   [[<cmd>lua vim.lsp.buf.rename()<cr>]], desc = "Rename the symbol under cursor" },
    { '<leader>l<CR>',   [[<cmd> lua vim.lsp.codelens.run()<cr>]], desc = "Run codelens at current line" },
  }

  -- Goto prev/next diag warning/error
  wk.register {
    g = {
      ['['] = { [[<cmd>lua require('ucw.keys.actions').diag_prev()<cr>]], "Go to previous diagnostic" },
      [']'] = { [[<cmd>lua require('ucw.keys.actions').diag_next()<cr>]], "Go to next diagnostic" },
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
    ['ic'] = { [[:<C-U>Gitsigns select_hunk<CR>]], "Select hunk (change) " },
  }, { mode = 'x' })
  wk.register({
    ['ic'] = { [[:<C-U>Gitsigns select_hunk<CR>]], "Select hunk (change) " },
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
      c = { [[<cmd>SessionSave<cr>]], "Manually save session" },
      r = { [[<cmd>SessionRestore<cr>]], "Manually restore session" },
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
