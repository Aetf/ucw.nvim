-- Everything that happens per client, per buffer, on a plain `LspAttach`
-- autocmd.
--
-- This replaces `ucw.lsp.hooks`, which offered three bespoke registration
-- points (`on_server_setup`, `on_new_config`, `on_attach`) installed by
-- monkey-patching nvim-lspconfig internals. Two of the three fired **zero**
-- times once servers started coming up through native `vim.lsp.enable()`,
-- taking every `ucw/lsp/lang/*.lua` module and the `.vscode/settings.json`
-- initial load down with them. `LspAttach` was the one part that always
-- worked, so it is the only part that survives.
--
-- The payoff: this fires for *every* client no matter who started it -
-- including rustaceanvim's, which never goes through lspconfig at all - so
-- there is no special case anywhere below.

local M = {}

-- Bare `g`-prefixed motions, buffer-local, live only while a client is
-- attached. Content is unchanged from the pre-Phase-3 `setup_keymap` (Phase 9
-- owns bindings); what changed is that they are declared against named actions
-- instead of duplicated rhs strings, and that they no longer use which-key v2's
-- deprecated `wk.register`.
local buffer_keys = {
  -- `code_action` is `mode = { 'n', 'x' }`, which is why the separate
  -- `<M-S-CR>` "range code actions" key is gone: it called
  -- `vim.lsp.buf.range_code_action`, removed from Neovim in 0.10, so it has
  -- only thrown errors since. `code_action()` reads the visual selection
  -- itself. Same story for `<leader>lA` in which-key.lua.
  ['<M-CR>'] = 'code_action',
  ['<M-S-r>'] = 'rename',
  ['<c-k>'] = 'diagnostic_float',
  ['g0'] = 'document_symbols',
  ['gW'] = 'workspace_symbols',
  ['ge'] = 'diagnostics',
  ['gD'] = 'implementations',
  ['gd'] = 'definitions',
  ['gt'] = 'type_definitions',
  ['gH'] = 'declaration',
  ['gr'] = 'references',
}

local function setup_keymaps(bufnr)
  local actions = require('ucw.lsp.actions')
  local spec = {}
  for lhs, name in pairs(buffer_keys) do
    table.insert(spec, actions.wk(lhs, name, { buffer = bufnr }))
  end
  require('which-key').add(spec)
end

---@param bufnr integer
local function setup_capabilities(bufnr)
  -- No `supports_method` guard on either of these, deliberately: both native
  -- entry points filter by capability themselves - `inlay_hint` requests only
  -- clients matching `method = 'textDocument/inlayHint'`
  -- (runtime/lua/vim/lsp/inlay_hint.lua:93), and the codelens capability is
  -- only instantiated for clients where `supports_method` holds
  -- (runtime/lua/vim/lsp/_capability.lua:146). A guard here would restate
  -- upstream behaviour, and the double-rendered inlay hints this phase fixes
  -- were never a missing guard - they were two rust-analyzer clients.
  vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

  -- `vim.lsp.codelens.refresh({ bufnr = ... })` is deprecated for removal in
  -- 0.13. Its replacement also subsumes the manual BufEnter/InsertLeave
  -- refresh augroup this used to carry: the native provider attaches to the
  -- buffer and re-requests on change (runtime/lua/vim/lsp/codelens.lua:47).
  vim.lsp.codelens.enable(true, { bufnr = bufnr })
end

function M.setup()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('ucw.lsp.attach', { clear = true }),
    desc = 'ucw: per-client LSP buffer setup',
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end
      setup_keymaps(args.buf)
      setup_capabilities(args.buf)
      require('ucw.lsp.vscode').attach(client)
    end,
  })
end

return M
