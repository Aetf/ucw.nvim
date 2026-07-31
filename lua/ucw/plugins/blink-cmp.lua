-- Completion. Replaces the old nvim-cmp cluster (nvim-cmp + cmp-buffer +
-- cmp-path + cmp-cmdline + cmp-nvim-lua + cmp-under-comparator + cmp-nvim-lsp
-- + cmp-nvim-lsp-signature-help + LuaSnip), 9 plugins collapsed into this one.
--
-- Snippets are handled by Neovim's native `vim.snippet` - blink.cmp's default
-- backend - so there is no snippet engine to configure. friendly-snippets is
-- likewise auto-detected by the built-in `snippets` source and only needs to be
-- present as a data dependency.
--
-- Everything set below differs from blink's defaults on purpose; anything the
-- old nvim-cmp config specified that blink already does by default (source
-- list, fuzzy backend, cmdline completion, nerd font variant, preselect) is
-- deliberately left out rather than restated.

return {
  'saghen/blink.cmp',
  lazy = false,
  -- tagged releases ship a prebuilt fuzzy-matcher binary, so no Rust toolchain
  -- is needed; `version` must stay a release tag for that to work.
  version = '1.*',
  dependencies = { 'rafamadriz/friendly-snippets' },
  opts = {
    -- `enter` rather than `default`, because it matches what the nvim-cmp setup
    -- actually bound: <CR> accepts, and <C-y> is left unmapped (nvim-cmp had it
    -- explicitly disabled). <Tab>/<S-Tab> move between snippet tabstops, which
    -- is also what Neovim 0.11+ maps them to natively - the old config's
    -- "Tab also walks the completion menu" chain is dropped in favour of
    -- <C-n>/<C-p>, so Tab means one thing again.
    keymap = {
      preset = 'enter',
      -- nvim-cmp's manual trigger
      ['<M-.>'] = { 'show', 'fallback' },
    },
    completion = {
      -- nvim-cmp showed documentation by default; blink does not
      documentation = { auto_show = true },
      -- nvim-cmp's `experimental.ghost_text`. Paired with auto_insert = false
      -- so the buffer only changes on accept: with both on you would get the
      -- preview inserted *and* ghosted.
      ghost_text = { enabled = true },
      list = { selection = { auto_insert = false } },
    },
    -- replaces cmp-nvim-lsp-signature-help. Upstream still labels this
    -- experimental; <C-k> toggles it, LSP trigger chars show it automatically.
    signature = { enabled = true },
    sources = {
      providers = {
        -- carried over from cmp-buffer's `keyword_length = 6`: buffer words are
        -- noisy, so only offer them once the prefix is long enough to be a real
        -- query. Under nvim-cmp buffer was additionally a second-tier fallback
        -- group; blink scores all sources together instead, so this threshold
        -- is now the only thing keeping buffer words out of short completions.
        buffer = { min_keyword_length = 6 },
      },
    },
  },
  -- so a file in lua/ucw/plugins/user/ can add a source without silently
  -- replacing the whole default list
  opts_extend = { 'sources.default' },
  config = function(_, opts)
    local blink = require('blink.cmp')
    blink.setup(opts)

    -- Replaces cmp-nvim-lsp: advertise the capabilities the completion engine
    -- actually implements (snippets, resolve support, label details, ...) to
    -- every server.
    --
    -- Deliberately NOT done through `ucw.lsp.register_on_server_setup`, which
    -- is what cmp-nvim-lsp used: that hook is installed by monkey-patching
    -- `lspconfig.util.on_setup`, but servers are enabled by mason-lspconfig's
    -- `automatic_enable`, which calls native `vim.lsp.enable()` and never goes
    -- through lspconfig's setup path. Verified empirically - the hook fires
    -- zero times with clients attached - so cmp-nvim-lsp's capability merge
    -- had silently stopped taking effect. `vim.lsp.config('*', ...)` is the
    -- native lowest-priority layer that `vim.lsp.enable()` does honour.
    --
    -- Passing include_nvim_defaults=true matters: blink only returns its own
    -- completion-related capabilities otherwise, which would drop everything
    -- Neovim advertises by default (signatureHelp, hover, ...).
    vim.lsp.config('*', { capabilities = blink.get_lsp_capabilities(nil, true) })
  end,
}
