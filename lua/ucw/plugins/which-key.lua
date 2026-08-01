local function config()
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

    { '<C-p>', [[<cmd>Telescope find_files<cr>]], desc = "Find File" },
    { '<M-S-f>', [[<cmd>Telescope live_grep<cr>]], desc = "Find in CWD" },
    { '<M-f>', [[<cmd>Telescope current_buffer_fuzzy_find<cr>]], desc = "Find in File" },
  }
  -- LSP.
  --
  -- `<leader>ll` ("Enable LSP") is gone: LSP comes up by itself now, on the
  -- FileType of a supported buffer. See lua/ucw/plugins/lspconfig.lua.
  --
  -- The right-hand sides come from `ucw.lsp.actions` rather than being spelled
  -- out here, because the same actions are also bound buffer-locally on bare
  -- `g` keys by `ucw.lsp.attach`. Two copies of the same `vim.lsp.*` call is
  -- how `<leader>lA` (range_code_action, removed from Neovim in 0.10) and
  -- `<leader>lH` (vim.lsp.declaration, never existed) went on being bound to
  -- nothing for years. Bindings themselves are Phase 9's business; this is
  -- only about where they are defined.
  local lsp_actions = require('ucw.lsp.actions')
  wk.add {
    { '<leader>l', group = 'LSP' },
    lsp_actions.wk('<leader>la', 'code_action'),
    lsp_actions.wk('<leader>l0', 'document_symbols'),
    lsp_actions.wk('<leader>lW', 'workspace_symbols'),
    lsp_actions.wk('<leader>le', 'diagnostics'),
    lsp_actions.wk('<leader>lD', 'implementations'),
    lsp_actions.wk('<leader>ld', 'definitions'),
    lsp_actions.wk('<leader>lt', 'type_definitions'),
    lsp_actions.wk('<leader>lH', 'declaration'),
    lsp_actions.wk('<leader>lr', 'references'),
    lsp_actions.wk('<leader>lh', 'document_highlight'),
    lsp_actions.wk('<leader>l<C-L>', 'clear_references'),
    lsp_actions.wk('<leader>lf', 'format'),
    lsp_actions.wk('<leader>lR', 'rename'),
    lsp_actions.wk('<leader>l<CR>', 'codelens_run'),
    lsp_actions.wk('<leader>lI', 'toggle_inlay_hint'),
    -- Not an `ucw.lsp.actions` entry: this is diagnostic *rendering*, not a
    -- per-client request, and it has no bare-`g` counterpart. It used to be
    -- defined by the lsp_lines.nvim spec, which Phase 4 deleted in favour of
    -- core's `virtual_lines` handler.
    {
      '<leader>lp',
      require('ucw.keys.actions').toggle_virtual_lines,
      desc = 'Toggle diagnostic virtual lines',
      -- lsp_lines bound this with `vim.keymap.set('', ...)`, i.e. normal +
      -- visual/select + operator-pending; which-key defaults to normal only.
      -- Operator-pending is meaningless for a toggle, the other two are not.
      mode = { 'n', 'v' },
    },
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

return {
  'folke/which-key.nvim',
  lazy = false,
  config = config,
}
