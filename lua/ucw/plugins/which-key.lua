local function config()
  local wk = require('which-key')
  wk.setup {
    plugins = {
      presets = {
        operators = false,
        motions = false,
      },
    },
  }
  -- Pickers. Phase 5 moved these from Telescope to snacks.picker; snacks has
  -- no ex-commands, so the right-hand sides are functions now.
  --
  -- `<leader>Tr` (`Telescope reloader`) is gone rather than ported - snacks has
  -- no equivalent source.
  wk.add {
    { '<leader>T', group = 'picker' },
    {
      '<leader>Th',
      function()
        Snacks.picker.command_history()
      end,
      desc = 'Command history',
    },

    {
      '<C-p>',
      function()
        Snacks.picker.files()
      end,
      desc = 'Find File',
    },
    {
      '<M-S-f>',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Find in CWD',
    },
    -- `lines` is snacks' name for what Telescope called
    -- `current_buffer_fuzzy_find`.
    {
      '<M-f>',
      function()
        Snacks.picker.lines()
      end,
      desc = 'Find in File',
    },
  }

  -- Messages and notifications.
  --
  -- The pain point this answers: message history used to be effectively
  -- unreadable. `Snacks.picker.noice` is the superset - noice registers that
  -- picker source itself when snacks.picker is present, and noice sees *all*
  -- message traffic, not only `vim.notify()` calls.
  wk.add {
    { '<leader>n', group = 'notifications' },
    {
      '<leader>nn',
      function()
        -- noice registers this picker source with snacks at runtime
        -- (`noice/init.lua`), so no annotation can know the field exists.
        ---@diagnostic disable-next-line: undefined-field
        Snacks.picker.noice()
      end,
      desc = 'Search all messages',
    },
    {
      '<leader>nh',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification history',
    },
    {
      '<leader>nd',
      function()
        require('noice').cmd('dismiss')
      end,
      desc = 'Dismiss notifications',
    },
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

  -- Goto prev/next diag warning/error.
  --
  -- These were dead from Phase 1 (the which-key v2 -> v3 conversion) until the
  -- Phase 3 acceptance review: the v2 form was `{ rhs, "description" }`, and
  -- the conversion put the *rhs* in `desc` and gave the entry no rhs at all.
  -- which-key accepts that happily - it just registers a label for a key that
  -- is not mapped - so `maparg('g[', 'n')` was empty and pressing the key did
  -- nothing, silently, for a month. Exactly what `ucw.lsp.actions` exists to
  -- prevent, three lines below the block it guards. tests/test_keys.lua now
  -- asserts these two really jump, and - generically - that no entry anywhere
  -- carries a right-hand side in its `desc`, which is the fingerprint of this
  -- mistake.
  wk.add {
    {
      'g[',
      function()
        require('ucw.keys.actions').diag_prev()
      end,
      desc = 'Go to previous diagnostic',
    },
    {
      'g]',
      function()
        require('ucw.keys.actions').diag_next()
      end,
      desc = 'Go to next diagnostic',
    },
  }

  -- Git
  wk.add {
    { '<leader>g', group = 'git' },
    { '<leader>gg', '<cmd>Neogit<cr>', desc = 'Neogit' },
    { '[c', "&diff ? ']c' : '<cmd>Gitsigns prev_hunk<CR>'", desc = 'Prev hunk', expr = true, replace_keycodes = false },
    { ']c', "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", desc = 'Next hunk', expr = true, replace_keycodes = false },
  }

  -- gitsigns
  wk.add {
    { '<leader>gR', '<cmd>Gitsigns reset_buffer<CR>', desc = 'Reset buffer' },
    { '<leader>gS', '<cmd>Gitsigns stage_buffer<CR>', desc = 'Stage buffer' },
    { '<leader>gb', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', desc = 'Blame line' },
    { '<leader>gd', '<cmd>Gitsigns diffthis<CR>', desc = 'Diff with index' },
    { '<leader>gh', '<cmd>DiffviewFileHistory<CR>', desc = 'History for current buffer' },
    { '<leader>gp', '<cmd>Gitsigns preview_hunk<CR>', desc = 'Preview hunk' },
    { '<leader>gr', '<cmd>Gitsigns reset_hunk<CR>', desc = 'Reset hunk' },
    { '<leader>gs', '<cmd>Gitsigns stage_hunk<CR>', desc = 'Stage hunk' },
    { '<leader>gt', group = 'toggles' },
    { '<leader>gtb', '<cmd>Gitsigns toggle_current_line_blame<CR>', desc = 'Toggle current line blame' },
    { '<leader>gtd', '<cmd>Gitsigns toggle_deleted<CR>', desc = 'Toggle deleted' },
    { '<leader>gu', '<cmd>Gitsigns undo_stage_hunk<CR>', desc = 'Undo stage hunk' },
  }
  wk.add {
    { '<leader>gr', ':Gitsigns reset_hunk<CR>', desc = 'Reset hunk', mode = 'v' },
    { '<leader>gs', ':Gitsigns stage_hunk<CR>', desc = 'Stage hunk', mode = 'v' },
  }
  -- text object
  wk.add {
    { 'ic', ':<C-U>Gitsigns select_hunk<CR>', desc = 'Select hunk (change) ', mode = 'x' },
    { 'ic', ':<C-U>Gitsigns select_hunk<CR>', desc = 'Select hunk (change) ', mode = 'o' },
  }

  -- Window and Buffer
  wk.add {
    { '<C-PageDown>', '<cmd>BufferLineCycleNext<cr>', desc = 'Go To Next Buffer' },
    { '<C-PageUp>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Go To Previous Buffer' },
    { '<M-Bar>', "<cmd>lua require('Navigator').tablast()<cr>", desc = 'Go to last tab' },
    { '<M-Bslash>', "<cmd>lua require('Navigator').previous()<cr>", desc = 'Go to last window' },
    { '<M-h>', "<cmd>lua require('Navigator').left()<cr>", desc = 'Go to left window' },
    { '<M-j>', "<cmd>lua require('Navigator').down()<cr>", desc = 'Go to down window' },
    { '<M-k>', "<cmd>lua require('Navigator').up()<cr>", desc = 'Go to up window' },
    { '<M-l>', "<cmd>lua require('Navigator').right()<cr>", desc = 'Go to right window' },
    { '<M-n>', "<cmd>lua require('Navigator').tabnext()<cr>", desc = 'Go to next tab' },
    { '<M-p>', "<cmd>lua require('Navigator').tabprev()<cr>", desc = 'Go to previous tab' },
    { '<S-Tab>', "<cmd>lua require('ucw.keys.actions').bufprev()<cr>", desc = 'Go to previous buffer' },
    { '<Tab>', "<cmd>lua require('ucw.keys.actions').bufnext()<cr>", desc = 'Go to next buffer' },
    { '<leader>`', '<C-^>', desc = 'Go To Alternvative Buffer' },
    { '<leader>b', group = 'buffer' },
    { '<leader>bX', "<cmd>lua require('ucw.keys.actions').bufdelete(0, true)<cr>", desc = 'Delete current buffer' },
    {
      '<leader>bb',
      function()
        Snacks.picker.buffers()
      end,
      desc = 'Go to buffer',
    },
    { '<leader>bd', '<cmd>BufferLinePickClose<cr>', desc = 'Pick Buffer To Close' },
    { '<leader>bx', "<cmd>lua require('ucw.keys.actions').bufdelete()<cr>", desc = 'Delete current buffer' },
    -- `:Session*` are auto-session's *legacy* command names (kept alive by its
    -- `legacy_cmds` option, which this config now turns off); the current ones
    -- are subcommands of `:AutoSession`, and the old spellings notify a
    -- deprecation warning at press time. `search` is the session picker that
    -- the deprecated `session-lens` plugin used to provide.
    { '<leader>s', group = 'session' },
    { '<leader>sc', '<cmd>AutoSession save<cr>', desc = 'Manually save session' },
    { '<leader>sr', '<cmd>AutoSession restore<cr>', desc = 'Manually restore session' },
    { '<leader>ss', '<cmd>AutoSession search<cr>', desc = 'Open session' },
    { '<leader>t', group = 'tab' },
    { '<leader>tc', '<cmd>tabnew<cr>', desc = 'Open new tab page' },
    { '<leader>tn', '<cmd>tabnext<cr>', desc = 'Go to next tab' },
    { '<leader>to', '<cmd>tabonly<cr>', desc = 'Close other tabs' },
    { '<leader>tp', '<cmd>tabprev<cr>', desc = 'Go to previous tab' },
    { '<leader>tx', '<cmd>tabclose<cr>', desc = 'Close current tab' },
    { '<leader>w', group = 'window' },
    { '<leader>wh', '<cmd>vsplit<cr>', desc = 'Create new window horizontally' },
    { '<leader>wv', '<cmd>split<cr>', desc = 'Create new window vertically' },
    { '<leader>wx', '<C-w>c', desc = 'Close current window' },
  }
  wk.add {
    {
      mode = { 't' },
      { '<M-Bslash>', "<cmd>lua require('Navigator').previous()<cr>", desc = 'Go to last window' },
      { '<M-h>', "<cmd>lua require('Navigator').left()<cr>", desc = 'Go to left window' },
      { '<M-j>', "<cmd>lua require('Navigator').down()<cr>", desc = 'Go to down window' },
      { '<M-k>', "<cmd>lua require('Navigator').up()<cr>", desc = 'Go to up window' },
      { '<M-l>', "<cmd>lua require('Navigator').right()<cr>", desc = 'Go to right window' },
    },
  }
end

return {
  'folke/which-key.nvim',
  lazy = false,
  config = config,
}
