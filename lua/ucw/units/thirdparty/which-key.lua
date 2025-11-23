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
  wk.add {
    { "g[", desc = "<cmd>lua require('ucw.keys.actions').diag_prev()<cr>" },
    { "g]", desc = "<cmd>lua require('ucw.keys.actions').diag_next()<cr>" },
  }

  -- Git
  wk.add {
    { "<leader>g", group = "git" },
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
    { "[c", "&diff ? ']c' : '<cmd>Gitsigns prev_hunk<CR>'", desc = "Prev hunk", expr = true, replace_keycodes = false },
    { "]c", "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", desc = "Next hunk", expr = true, replace_keycodes = false },
  }

  -- gitsigns
  wk.add {
    { "<leader>gR", "<cmd>Gitsigns reset_buffer<CR>", desc = "Reset buffer" },
    { "<leader>gS", "<cmd>Gitsigns stage_buffer<CR>", desc = "Stage buffer" },
    { "<leader>gb", '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', desc = "Blame line" },
    { "<leader>gd", "<cmd>Gitsigns diffthis<CR>", desc = "Diff with index" },
    { "<leader>gh", "<cmd>DiffviewFileHistory<CR>", desc = "History for current buffer" },
    { "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "Preview hunk" },
    { "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", desc = "Reset hunk" },
    { "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", desc = "Stage hunk" },
    { "<leader>gt", group = "toggles" },
    { "<leader>gtb", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "Toggle current line blame" },
    { "<leader>gtd", "<cmd>Gitsigns toggle_deleted<CR>", desc = "Toggle deleted" },
    { "<leader>gu", "<cmd>Gitsigns undo_stage_hunk<CR>", desc = "Undo stage hunk" },
  }
  wk.add {
    { "<leader>gr", ":Gitsigns reset_hunk<CR>", desc = "Reset hunk", mode = "v" },
    { "<leader>gs", ":Gitsigns stage_hunk<CR>", desc = "Stage hunk", mode = "v" },
  }
  -- text object
  wk.add {
    { "ic", ":<C-U>Gitsigns select_hunk<CR>", desc = "Select hunk (change) ", mode = "x" },
    { "ic", ":<C-U>Gitsigns select_hunk<CR>", desc = "Select hunk (change) ", mode = "o" },
  }

  -- Window and Buffer
  wk.add {
    { "<C-PageDown>", "<cmd>BufferLineCycleNext<cr>", desc = "Go To Next Buffer" },
    { "<C-PageUp>", "<cmd>BufferLineCyclePrev<cr>", desc = "Go To Previous Buffer" },
    { "<M-Bar>", "<cmd>lua require('Navigator').tablast()<cr>", desc = "Go to last tab" },
    { "<M-Bslash>", "<cmd>lua require('Navigator').previous()<cr>", desc = "Go to last window" },
    { "<M-h>", "<cmd>lua require('Navigator').left()<cr>", desc = "Go to left window" },
    { "<M-j>", "<cmd>lua require('Navigator').down()<cr>", desc = "Go to down window" },
    { "<M-k>", "<cmd>lua require('Navigator').up()<cr>", desc = "Go to up window" },
    { "<M-l>", "<cmd>lua require('Navigator').right()<cr>", desc = "Go to right window" },
    { "<M-n>", "<cmd>lua require('Navigator').tabnext()<cr>", desc = "Go to next tab" },
    { "<M-p>", "<cmd>lua require('Navigator').tabprev()<cr>", desc = "Go to previous tab" },
    { "<S-Tab>", "<cmd>lua require('ucw.keys.actions').bufprev()<cr>", desc = "Go to previous buffer" },
    { "<Tab>", "<cmd>lua require('ucw.keys.actions').bufnext()<cr>", desc = "Go to next buffer" },
    { "<leader>`", "<C-^>", desc = "Go To Alternvative Buffer" },
    { "<leader>b", group = "buffer" },
    { "<leader>bX", "<cmd>lua require('ucw.keys.actions').bufdelete(0, true)<cr>", desc = "Delete current buffer" },
    { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Go to buffer" },
    { "<leader>bd", "<cmd>BufferLinePickClose<cr>", desc = "Pick Buffer To Close" },
    { "<leader>bx", "<cmd>lua require('ucw.keys.actions').bufdelete()<cr>", desc = "Delete current buffer" },
    { "<leader>s", group = "session" },
    { "<leader>sc", "<cmd>SessionSave<cr>", desc = "Manually save session" },
    { "<leader>sr", "<cmd>SessionRestore<cr>", desc = "Manually restore session" },
    { "<leader>ss", "<cmd>Telescope session-lens search_session<cr>", desc = "Open session" },
    { "<leader>t", group = "tab" },
    { "<leader>tc", "<cmd>tabnew<cr>", desc = "Open new tab page" },
    { "<leader>tn", "<cmd>tabnext<cr>", desc = "Go to next tab" },
    { "<leader>to", "<cmd>tabonly<cr>", desc = "Close other tabs" },
    { "<leader>tp", "<cmd>tabprev<cr>", desc = "Go to previous tab" },
    { "<leader>tx", "<cmd>tabclose<cr>", desc = "Close current tab" },
    { "<leader>w", group = "window" },
    { "<leader>wh", "<cmd>vsplit<cr>", desc = "Create new window horizontally" },
    { "<leader>wv", "<cmd>split<cr>", desc = "Create new window vertically" },
    { "<leader>wx", "<C-w>c", desc = "Close current window" },
  }
  wk.add {
    {
      mode = { "t" },
      { "<M-Bslash>", "<cmd>lua require('Navigator').previous()<cr>", desc = "Go to last window" },
      { "<M-h>", "<cmd>lua require('Navigator').left()<cr>", desc = "Go to left window" },
      { "<M-j>", "<cmd>lua require('Navigator').down()<cr>", desc = "Go to down window" },
      { "<M-k>", "<cmd>lua require('Navigator').up()<cr>", desc = "Go to up window" },
      { "<M-l>", "<cmd>lua require('Navigator').right()<cr>", desc = "Go to right window" },
    },
  }
end

return M
