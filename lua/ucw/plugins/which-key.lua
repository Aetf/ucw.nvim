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
  -- live in this file (Phase 8, D1), registered eagerly, so every group is
  -- discoverable at boot even when its owner has not loaded yet - see the
  -- `wk.add` blocks below. `<leader>n` is no longer one of them (Phase 9,
  -- D7): it is a single key now (notification history, in `snacks.lua`).
  -- `<leader>c` = code (Phase 9, D2): actions on the code under the cursor,
  -- LazyVim's letters exactly. The old 14-key `<leader>l` tree is gone -
  -- goto/list keys have no leader duplicates, the gr* shapes below are the
  -- only door (six of those entries were pure copies; `<leader>lA` and
  -- `<leader>lH` were bound to functions that no longer/never existed, which
  -- is why the rhs come from `ucw.lsp.actions` by name). The manual
  -- document-highlight pair (`lh`/`l<C-L>`) is replaced by automatic
  -- reference highlighting (snacks.words, see snacks.lua).
  local lsp_actions = require('ucw.lsp.actions')
  wk.add {
    { '<leader>c', group = 'code' },
    lsp_actions.wk('<leader>ca', 'code_action'),
    lsp_actions.wk('<leader>cr', 'rename'),
    lsp_actions.wk('<leader>cf', 'format'),
    lsp_actions.wk('<leader>cl', 'codelens_run'),
  }

  -- `<leader>s` = search (Phase 9, D3). Most members are `keys =` entries in
  -- `snacks.lua` (+ `sm` in `noice.lua`); these four are LSP-backed, so
  -- their rhs resolve through `ucw.lsp.actions` like every other LSP entry
  -- point. `ss` and `gO` share one action on purpose - search semantics
  -- rather than a goto duplicate - and `sS` is workspace symbols' only door
  -- since D1 deleted `gW`.
  -- `<leader>f` = find (files; keys in snacks.lua), `<leader>s` = search
  -- (content), `<leader>r` = REPL (keys in iron.lua).
  wk.add {
    { '<leader>f', group = 'find' },
    { '<leader>r', group = 'REPL' },
    { '<leader>s', group = 'search' },
    lsp_actions.wk('<leader>ss', 'document_symbols'),
    lsp_actions.wk('<leader>sS', 'workspace_symbols'),
    lsp_actions.wk('<leader>sd', 'diagnostics'),
    lsp_actions.wk('<leader>sD', 'diagnostics_all'),
  }

  -- `<leader>u` = toggles/UI (Phase 9, D4): every on/off state in the
  -- config, one prefix. The keys are `Snacks.toggle`s - stateful in this
  -- popup - registered in `ucw.toggles` (editor-core: uh/uv/uD/uw/us) and
  -- `gitsigns.lua` (ub/ud); `un` (dismiss notifications) is a `keys =`
  -- entry in `noice.lua`.
  wk.add { { '<leader>u', group = 'toggles/UI' } }
  require('ucw.toggles').setup()

  -- `<leader>l` = the plugin manager (Phase 9, D2) - literally LazyVim's own
  -- binding, on the letter the dissolved LSP tree freed. `:checkhealth ucw`
  -- stays keyless on purpose (low frequency).
  wk.add { { '<leader>l', '<cmd>Lazy<cr>', desc = 'Plugin manager (Lazy)' } }

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

  -- The native gr* vocabulary (Phase 9, D1): the lhs are Neovim's own 0.11+
  -- global defaults, so the *keys* need no maintenance here - only the
  -- right-hand sides change, list-producing keys open a snacks picker
  -- instead of the quickfix/location list. `grn`/`gra`/`grx` stay fully
  -- native and are deliberately not restated. `gd`/`gD` are buffer-local in
  -- `ucw.lsp.attach` (they replace native *motions*, so they exist only
  -- where a client is attached); these four replace native *mappings* and
  -- so are global like the defaults they shadow.
  wk.add {
    lsp_actions.wk('grr', 'references'),
    lsp_actions.wk('gri', 'implementations'),
    lsp_actions.wk('grt', 'type_definitions'),
    lsp_actions.wk('gO', 'document_symbols'),
  }

  -- Git group headers; the keys are `keys =` entries in `gitsigns.lua`,
  -- `neogit.lua`, `diffview.lua` and `octo.lua` (Phase 8, D1/D3). octo's
  -- header lives here *eagerly* on purpose: its keys are lazy-load stubs, and
  -- before Phase 8 the whole subtree was invisible until the first `:Octo`.
  -- The `<leader>gt` toggle subtree is gone (Phase 9, D4): its two members
  -- are `<leader>ub`/`<leader>ud` now, with every other toggle.
  wk.add {
    { '<leader>g', group = 'git' },
    { '<leader>go', group = 'octo (GitHub)' },
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
    { '<leader>q', group = 'quit/session' },
    { '<leader>qq', '<cmd>qa<cr>', desc = 'Quit all' },
    { '<leader>t', group = 'tab' },
    { '<leader>tc', '<cmd>tabnew<cr>', desc = 'Open new tab page' },
    { '<leader>tn', '<cmd>tabnext<cr>', desc = 'Go to next tab' },
    { '<leader>to', '<cmd>tabonly<cr>', desc = 'Close other tabs' },
    { '<leader>tp', '<cmd>tabprev<cr>', desc = 'Go to previous tab' },
    { '<leader>tx', '<cmd>tabclose<cr>', desc = 'Close current tab' },
    -- Window keys use `<C-w>`'s own letters (Phase 9, D10): ws = :split,
    -- wv = :vsplit. `wv` used to mean the *other* split and `wh` is gone -
    -- accepted churn for vocabulary that matches native `<C-w>s`/`<C-w>v`.
    -- Everything else window-shaped stays on `<M-hjkl>` (navigator.lua) and
    -- which-key's `<C-w>` preset.
    { '<leader>w', group = 'window' },
    { '<leader>ws', '<cmd>split<cr>', desc = 'Split window horizontally' },
    { '<leader>wv', '<cmd>vsplit<cr>', desc = 'Split window vertically' },
    { '<leader>wx', '<C-w>c', desc = 'Close current window' },
  }
end

return {
  'folke/which-key.nvim',
  lazy = false,
  -- Not under vscode-neovim (Phase 9, D9): it renders no nvim floats and
  -- owns buffers/windows/tabs itself - upstream recommends disabling UI
  -- plugins. Everything this file registers goes with it there, coherently:
  -- the trees are pickers (no floats), buffer/window/tab lifecycle (vscode's
  -- own), and toggles for nvim-side rendering vscode does not use. firenvim
  -- keeps all of it - a real nvim UI where discoverability matters most.
  -- `ucw.lsp.attach` stopped requiring which-key in D1, so LSP buffers keep
  -- working either way.
  cond = function()
    return not require('ucw.targets').is_vscode()
  end,
  -- for `ucw.toggles`: both eager, but `Snacks` must exist when `config()`
  -- runs, and lazy.nvim only guarantees order through `dependencies`
  dependencies = { 'folke/snacks.nvim' },
  config = config,
}
