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

-- Buffer-local keys, live only while a client is attached. Phase 9 (D1)
-- shrank this from eleven bare `g` keys to four: the pre-0.11 set shadowed
-- native motions in every LSP buffer (`ge` backward word-end, `g0`
-- display-line start, `gt` next tab) and sat `gr` on what is now the native
-- `gr*` prefix. The native vocabulary took over - `grr`/`gri`/`grt`/`gO`
-- get picker-backed right-hand sides globally in `which-key.lua` - leaving
-- here only the two motions whose native meaning this config deliberately
-- supersedes (`gd`/`gD`, P3: strictly-superseding and community-mainstream)
-- and two accelerators. `gD` means *declaration* now, per its native
-- reading; it used to mean implementations, which live on `gri`.
--
-- Bare `vim.keymap.set`, not `which-key.add` (D9): this module runs in
-- targets where which-key is deliberately absent, and a bare require of a
-- deliberately-absent plugin is the exact seam Phase 6's R1 broke on.
local buffer_keys = {
  -- `code_action` is `mode = { 'n', 'x' }`: `code_action()` reads the visual
  -- selection itself since 0.10, which is why there is no separate range key.
  ['<M-CR>'] = 'code_action',
  ['<c-k>'] = 'diagnostic_float',
  ['gd'] = 'definitions',
  ['gD'] = 'declaration',
}

local function setup_keymaps(bufnr)
  local actions = require('ucw.lsp.actions')
  for lhs, name in pairs(buffer_keys) do
    local action = actions.actions[name]
    -- `silent = true` to match what the which-key registration had (Phase 8
    -- acceptance review R1: which-key defaults silent, `vim.keymap.set` not)
    vim.keymap.set(action.mode or 'n', lhs, actions.rhs(name), {
      buffer = bufnr,
      desc = action.desc,
      silent = true,
    })
  end
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

  -- `is_enabled()` with no filter reads the *global* flag, which `M.setup()`
  -- seeds to `true` and `<leader>lI` flips: it is the user's preference, and
  -- this line is what carries it to a buffer that did not exist when the key
  -- was pressed. Passing a literal `true` here instead is what made the toggle
  -- unable to stick (Phase 3 acceptance review, P1).
  --
  -- The buffer-local write is not redundant with inheriting the global flag:
  -- upstream's own `LspDetach` handler calls `_disable(bufnr)` when the last
  -- inlay-capable client leaves (inlay_hint.lua:301), which *rawsets*
  -- `enabled = false` on the buffer while the global flag is true. Without
  -- re-asserting here, a `:LspRestart` or a server crash would leave that
  -- buffer with hints off forever.
  vim.lsp.inlay_hint.enable(vim.lsp.inlay_hint.is_enabled(), { bufnr = bufnr })

  -- `vim.lsp.codelens.refresh({ bufnr = ... })` is deprecated for removal in
  -- 0.13. Its replacement also subsumes the manual BufEnter/InsertLeave
  -- refresh augroup this used to carry: the native provider attaches to the
  -- buffer and re-requests on change (runtime/lua/vim/lsp/codelens.lua:47).
  vim.lsp.codelens.enable(true, { bufnr = bufnr })
end

function M.setup()
  -- Inlay hints are on by default, expressed as the *global* flag rather than
  -- as a literal `true` at attach time. That flag is what
  -- `vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())` - the
  -- upstream-documented toggle idiom, and what `<leader>lI` runs - reads and
  -- writes. Seeding it here is what makes the first press turn hints *off*:
  -- before, attach set only the buffer flag, the global one stayed `false`,
  -- and the first press "enabled" hints that were already on.
  vim.lsp.inlay_hint.enable(true)

  -- the matching LspDetach half, so `.vscode/settings.json` watchers do not
  -- outlive the client that wanted them
  require('ucw.lsp.vscode').setup()

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
