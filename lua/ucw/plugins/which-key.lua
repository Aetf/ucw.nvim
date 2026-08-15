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
  -- Group headers for trees whose keys live with their owning plugin specs
  -- (Phase 8, D1). The keys themselves are `keys =` entries in `snacks.lua`
  -- (pickers, notification history), `noice.lua` (message search/dismiss),
  -- `gitsigns.lua`, `neogit.lua`, `diffview.lua`, `bufferline.lua`,
  -- `auto-session.lua`, `navigator.lua`, `octo.lua`, `iron.lua`. Headers stay
  -- here, registered eagerly, so every group is discoverable at boot even
  -- when its owner has not loaded yet.
  wk.add {
    { '<leader>T', group = 'picker' },
    { '<leader>n', group = 'notifications' },
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

  -- Git group headers; the keys are `keys =` entries in `gitsigns.lua`,
  -- `neogit.lua` and `diffview.lua` (Phase 8, D1).
  wk.add {
    { '<leader>g', group = 'git' },
    { '<leader>gt', group = 'toggles' },
  }

  -- Window and Buffer: core-editor keys only. Plugin-owned ones moved to
  -- their specs (Phase 8, D1): window/tab *navigation* to `navigator.lua`,
  -- `<C-PageDown/Up>` + `<leader>bd` to `bufferline.lua`, `<leader>bb` to
  -- `snacks.lua`, `<leader>s*` session keys to `auto-session.lua`.
  --
  -- `<Tab>`/`<S-Tab>` stay: `ucw.keys.actions.bufnext/bufprev` *prefer*
  -- bufferline but fall back to `:bnext`/`:bprev`, so they are not owned by
  -- any plugin - they work in every target.
  wk.add {
    { '<S-Tab>', "<cmd>lua require('ucw.keys.actions').bufprev()<cr>", desc = 'Go to previous buffer' },
    { '<Tab>', "<cmd>lua require('ucw.keys.actions').bufnext()<cr>", desc = 'Go to next buffer' },
    { '<leader>`', '<C-^>', desc = 'Go To Alternvative Buffer' },
    { '<leader>b', group = 'buffer' },
    { '<leader>bX', "<cmd>lua require('ucw.keys.actions').bufdelete(0, true)<cr>", desc = 'Delete current buffer' },
    { '<leader>bx', "<cmd>lua require('ucw.keys.actions').bufdelete()<cr>", desc = 'Delete current buffer' },
    { '<leader>s', group = 'session' },
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
end

return {
  'folke/which-key.nvim',
  lazy = false,
  config = config,
}
