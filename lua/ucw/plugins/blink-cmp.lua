-- Completion. Replaces the old nvim-cmp cluster (nvim-cmp + cmp-buffer +
-- cmp-path + cmp-cmdline + cmp-nvim-lua + cmp-under-comparator + cmp-nvim-lsp
-- + cmp-nvim-lsp-signature-help + LuaSnip), 9 plugins collapsed into this one.
--
-- Snippets are handled by Neovim's native `vim.snippet` - that is blink.cmp's
-- default backend, so there is no snippet engine to configure. friendly-snippets
-- is likewise auto-detected by the built-in `snippets` source and only needs to
-- be present as a data dependency.

-- Old nvim-cmp bound <Tab> to "complete" only when there is a non-blank char
-- before the cursor, so <Tab> at indentation still indents. blink has no
-- equivalent built-in command, so keep the predicate.
local function has_words_before()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
end

return {
  'saghen/blink.cmp',
  lazy = false,
  -- tagged releases ship a prebuilt fuzzy-matcher binary, so no Rust toolchain
  -- is needed; `version` must stay a release tag for that to work.
  version = '1.*',
  dependencies = { 'rafamadriz/friendly-snippets' },
  opts = {
    keymap = {
      preset = 'default',
      -- Faithful port of the old nvim-cmp <Tab>/<S-Tab> chain: move in the
      -- menu first, then jump snippet tabstops, then open the menu. Each
      -- command returns false when it does not apply, falling through.
      ['<Tab>'] = {
        'select_next',
        'snippet_forward',
        function(cmp)
          if has_words_before() then return cmp.show() end
        end,
        'fallback',
      },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
      ['<CR>'] = { 'accept', 'fallback' },
      ['<M-.>'] = { 'show', 'fallback' },
      -- was explicitly disabled under nvim-cmp; keep it free
      ['<C-y>'] = false,
    },
    appearance = { nerd_font_variant = 'mono' },
    completion = {
      -- nvim-cmp showed docs by default, so this is parity rather than a new
      -- behaviour; the delay keeps it from flickering while cycling items.
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      -- old config used experimental.ghost_text instead of inserting text as
      -- you move through the list
      ghost_text = { enabled = true },
      list = { selection = { preselect = true, auto_insert = false } },
    },
    signature = {
      -- replaces cmp-nvim-lsp-signature-help. Upstream still labels this
      -- experimental; <C-k> toggles it, LSP trigger chars show it automatically.
      enabled = true,
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
      providers = {
        -- carried over from cmp-buffer's `keyword_length = 6`: buffer words are
        -- noisy, so only offer them once the prefix is long enough to be a real
        -- query. Under nvim-cmp buffer was additionally a second-tier fallback
        -- group; blink scores all sources together instead, which surfaces
        -- buffer words a little more often than before.
        buffer = { min_keyword_length = 6 },
      },
    },
    cmdline = {
      -- replaces cmp-cmdline
      enabled = true,
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
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
