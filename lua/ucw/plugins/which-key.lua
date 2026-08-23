local function config()
  local wk = require('which-key')
  wk.setup {
    plugins = {
      presets = {
        -- Inherited from the pre-lazy config and kept deliberately in the
        -- trial period. `operators` labels `d`/`c`/`y`/`gw`/... and `motions`
        -- labels `hjkl`/`w`/`b`/`f`/`t`: rows for keys nobody in this config
        -- has to look up, on triggers that fire in the middle of typing an
        -- operator. What is genuinely forgettable up there is the reflow pair,
        -- and `gq` is not in either preset anyway - so it is labelled by hand
        -- at the bottom of this file, at zero cost to every other key.
        operators = false,
        motions = false,
      },
    },
  }

  -- `<leader>`'s first level, the one popup that is always one keypress away,
  -- follows two rules (trial-period cleanup):
  --
  -- 1. **Labels.** Group labels are lowercase nouns naming the space
  --    (`buffer`, `code`, `repl`, `toggle/ui`); proper nouns keep their own
  --    spelling (`Lazy`, `GitHub`). Leaf labels are Sentence-case verb
  --    phrases (`Plugin manager (Lazy)`). So the `+` prefix and the case both
  --    say "group" vs "action", instead of `REPL` and `toggles/UI` standing
  --    out for no reason.
  --
  -- 2. **Icons are explicit.** which-key otherwise picks them by matching
  --    keywords against the *description* (`which-key/icons.lua`'s `rules`),
  --    which is luck, not design: `repl` matched no rule at all and rendered
  --    blank, while `Go to alternate buffer` and `Buffer-local keymaps` both
  --    matched `buffer` and came out as file icons. Every first-level entry
  --    below carries its own `icon`, including the ones whose keys are owned
  --    by another spec. tests/test_keys.lua asserts both rules so a new entry
  --    cannot quietly go back to guessing.
  --
  -- Group headers are registered for normal *and* visual mode. `wk.add`
  -- defaults to `n` only, which is why visual-mode `<leader>` used to render
  -- `c -> +2 keymaps` with no name and no icon; the members were always
  -- there (`<leader>ca`, `<leader>sw`, `<leader>r*`, ...), only their headers
  -- were not. Headers whose subtree has no visual-mode member simply do not
  -- appear there.
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
    { '<leader>c', group = 'code', mode = { 'n', 'x' }, icon = { icon = '', color = 'orange' } },
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
    { '<leader>f', group = 'find', mode = { 'n', 'x' }, icon = { icon = '', color = 'green' } },
    { '<leader>r', group = 'repl', mode = { 'n', 'x' }, icon = { icon = '', color = 'red' } },
    { '<leader>s', group = 'search', mode = { 'n', 'x' }, icon = { icon = '', color = 'green' } },
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
  wk.add { { '<leader>u', group = 'toggle/ui', mode = { 'n', 'x' }, icon = { icon = '', color = 'yellow' } } }
  require('ucw.toggles').setup()

  -- The two first-level entries whose *keys* live in another spec, here only
  -- for their icon (rule 2 at the top of this file). A `wk.add` entry with no
  -- rhs and no desc adds nothing to the popup on its own - it merges into the
  -- node the real mapping already created - which is exactly the "label for a
  -- key that is not mapped" shape the `g[`/`g]` comment below warns about,
  -- used on purpose this time. `<leader>n`'s own icon was snacks.nvim's
  -- plugin icon (which-key credits a key to the plugin that owns it, so every
  -- snacks-owned key wants to look the same); `\`'s file-tree accelerators
  -- are not under `<leader>` at all and keep neo-tree's.
  wk.add {
    { '<leader>n', icon = { icon = '󰵅', color = 'blue' } },
  }

  -- `<leader>l` = the plugin manager (Phase 9, D2) - literally LazyVim's own
  -- binding, on the letter the dissolved LSP tree freed. `:checkhealth ucw`
  -- stays keyless on purpose (low frequency).
  wk.add { { '<leader>l', '<cmd>Lazy<cr>', desc = 'Plugin manager (Lazy)', icon = { icon = '󰒲', color = 'blue' } } }

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
  -- `neogit.lua`, `codediff.lua` and `octo.lua` (Phase 8, D1/D3). octo's
  -- header lives here *eagerly* on purpose: its keys are lazy-load stubs, and
  -- before Phase 8 the whole subtree was invisible until the first `:Octo`.
  -- The `<leader>gt` toggle subtree is gone (Phase 9, D4): its two members
  -- are `<leader>ub`/`<leader>ud` now, with every other toggle.
  wk.add {
    { '<leader>g', group = 'git', mode = { 'n', 'x' }, icon = { icon = '󰊢', color = 'orange' } },
    { '<leader>go', group = 'octo (GitHub)', icon = { icon = '', color = 'purple' } },
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
    { '<leader>`', '<C-^>', desc = 'Go to alternate buffer', icon = { icon = '󰬲', color = 'cyan' } },
    -- P6, searchability: the buffer-local complement to `<leader>sk` (all
    -- keymaps, snacks picker).
    {
      '<leader>?',
      function()
        require('which-key').show { global = false }
      end,
      desc = 'Buffer-local keymaps (which-key)',
      icon = { icon = '󰌌', color = 'cyan' },
    },
    { '<leader>b', group = 'buffer', mode = { 'n', 'x' }, icon = { icon = '󰈔', color = 'cyan' } },
    { '<leader>bX', "<cmd>lua require('ucw.keys.actions').bufdelete(0, true)<cr>", desc = 'Delete current buffer' },
    { '<leader>bx', "<cmd>lua require('ucw.keys.actions').bufdelete()<cr>", desc = 'Delete current buffer' },
    { '<leader>q', group = 'quit/session', mode = { 'n', 'x' }, icon = { icon = '', color = 'azure' } },
    { '<leader>qq', '<cmd>qa<cr>', desc = 'Quit all' },
    { '<leader>t', group = 'tab', mode = { 'n', 'x' }, icon = { icon = '󰓩', color = 'purple' } },
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
    { '<leader>w', group = 'window', mode = { 'n', 'x' }, icon = { icon = '', color = 'blue' } },
    { '<leader>ws', '<cmd>split<cr>', desc = 'Split window horizontally' },
    { '<leader>wv', '<cmd>vsplit<cr>', desc = 'Split window vertically' },
    { '<leader>wx', '<C-w>c', desc = 'Close current window' },
  }

  -- Labels only, for two *built-in* operators this config never remaps: they
  -- have no rhs here, so nothing is mapped and the keymap snapshot does not
  -- move - the entries exist so `g` lists them. This is the one place the
  -- `operators` preset was wanted (it is off, see `wk.setup` above), and it
  -- would not have covered `gq`, which is in no preset at all.
  --
  -- The two are not interchangeable, which is the reason to spell out the
  -- distinction where it is read rather than in `:h gq`:
  --
  -- * `gq` runs 'formatexpr' when one is set. Neovim's own LSP client sets
  --   `formatexpr=v:lua.vim.lsp.formatexpr()` on attach whenever the server
  --   offers range formatting (`runtime/lua/vim/lsp.lua`), and `ftplugin/tex.lua`
  --   sets its own sentence-per-line one - so in those buffers `gq` is "ask
  --   the formatter", not "wrap at 'textwidth'".
  -- * `gw` ignores 'formatexpr'/'formatprg' (`:h gw`) and always does the
  --   built-in wrap at 'textwidth' (80 here), keeping the cursor put. For
  --   prose, this is the one that does what "reflow" means.
  wk.add {
    { 'gq', desc = "Reflow (via 'formatexpr': LSP/ftplugin, else wrap)", mode = { 'n', 'x' } },
    { 'gw', desc = "Reflow at 'textwidth', keep cursor", mode = { 'n', 'x' } },
  }

  -- Labels for keys owned by a plugin or by Neovim itself, which is the other
  -- half of the same problem the `<leader>` rules above solve: which-key
  -- renders a mapping's `desc`, and when there is none it falls back to
  -- *displaying the rhs*. Entering visual mode therefore drew a wall of
  -- `Lightspeed_f`, `MatchitVisualForward)`, `help v_star-default` and six
  -- blank rows (neoscroll's scroll keys, which are Lua functions - nothing to
  -- print at all).
  --
  -- Labels only, exactly like `gq`/`gw` above: no rhs, so nothing is mapped or
  -- remapped and the keymap snapshot does not move. The plugin keeps owning
  -- the behaviour; this only names it.
  --
  -- Modes are per key, matching where the mapping actually exists, because a
  -- label on a mode that has no such mapping is a row for a key that does
  -- nothing - the `g[`/`g]` bug in popup form. `lightspeed` and `neoscroll`
  -- are both `lazy = false` with no `cond`, so their keys are never absent
  -- while these labels are present.
  local nxo = { 'n', 'x', 'o' }
  wk.add {
    -- lightspeed: `s`/`gs` are remapped to the bidirectional variants in
    -- lightspeed.lua, the rest are the plugin's own defaults. `x`/`X`/`z`/`Z`
    -- exist in operator-pending only, where `s`/`S` would collide with the
    -- native operators.
    { 'f', desc = 'Jump to char (lightspeed)', mode = nxo },
    { 'F', desc = 'Jump back to char (lightspeed)', mode = nxo },
    { 't', desc = 'Jump before char (lightspeed)', mode = nxo },
    { 'T', desc = 'Jump back before char (lightspeed)', mode = nxo },
    { 's', desc = 'Jump to 2-char match (lightspeed)', mode = { 'n', 'x' } },
    { 'S', desc = 'Jump back to 2-char match (lightspeed)', mode = { 'n', 'x' } },
    { 'z', desc = 'Jump to 2-char match (lightspeed)', mode = 'o' },
    { 'Z', desc = 'Jump back to 2-char match (lightspeed)', mode = 'o' },
    { 'x', desc = 'Jump to 2-char match, inclusive (lightspeed)', mode = 'o' },
    { 'X', desc = 'Jump back to 2-char match, inclusive (lightspeed)', mode = 'o' },
    { 'gs', desc = 'Jump to 2-char match across windows (lightspeed)', mode = 'n' },
    { 'gS', desc = 'Jump back to 2-char match across windows (lightspeed)', mode = 'n' },
    { ';', desc = 'Repeat jump (lightspeed)', mode = nxo },
    { ',', desc = 'Repeat jump backwards (lightspeed)', mode = nxo },

    -- matchit (a Neovim runtime plugin). `%` is the native key it extends
    -- from brackets to language keywords; the rest are matchit's own.
    { '%', desc = 'Go to matching bracket or keyword', mode = nxo },
    { 'g%', desc = 'Go to previous match in the group', mode = nxo },
    { '[%', desc = 'Go to start of the enclosing group', mode = nxo },
    { ']%', desc = 'Go to end of the enclosing group', mode = nxo },
    { 'a%', desc = 'around matching group', mode = { 'x', 'o' } },

    -- neoscroll: the same six scroll keys and three `z` placements as the
    -- built-ins, animated. In visual mode all nine drew as blank rows.
    { '<C-b>', desc = 'Scroll page up (smooth)', mode = { 'n', 'x' } },
    { '<C-f>', desc = 'Scroll page down (smooth)', mode = { 'n', 'x' } },
    { '<C-u>', desc = 'Scroll half page up (smooth)', mode = { 'n', 'x' } },
    { '<C-d>', desc = 'Scroll half page down (smooth)', mode = { 'n', 'x' } },
    { '<C-y>', desc = 'Scroll one line up (smooth)', mode = { 'n', 'x' } },
    { '<C-e>', desc = 'Scroll one line down (smooth)', mode = { 'n', 'x' } },
    { 'zt', desc = 'This line to top (smooth)', mode = { 'n', 'x' } },
    { 'zz', desc = 'This line to centre (smooth)', mode = { 'n', 'x' } },
    { 'zb', desc = 'This line to bottom (smooth)', mode = { 'n', 'x' } },

    -- Neovim's own visual-mode defaults. Their descs are deliberately written
    -- as help tags (`:help v_star-default`), which is a fine thing for
    -- `:map` to print and a poor row in a popup.
    { '*', desc = 'Search forward for the selection', mode = 'x' },
    { '#', desc = 'Search backward for the selection', mode = 'x' },
    { '@', desc = 'Run a register on the selected lines', mode = 'x' },
    { 'Q', desc = 'Run the last recorded register on the selected lines', mode = 'x' },
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
