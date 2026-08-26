-- Rust is the one asymmetry in the LSP design: rustaceanvim owns its
-- rust-analyzer client on purpose (that is what gives standalone non-Cargo
-- files, reload-workspace, grouped code actions, runnables/testables,
-- expand-macro and view HIR/MIR), and its README is explicit that a second
-- externally-started client causes conflicts. So `rust_analyzer` is absent from
-- `ucw.lsp.servers` and mason-lspconfig no longer auto-enables one - that pair
-- is what used to attach two clients to every Rust buffer and render every
-- inlay hint twice.
--
-- Everything else is uniform: attach behaviour rides on `LspAttach`, which
-- fires for this client like any other.
return {
  'mrcjkb/rustaceanvim',
  cond = require('ucw.targets').is_full_ui,
  ft = { 'rust' },
  -- Same reason nvim-lspconfig depends on it: `mason.setup()` is what puts
  -- `<data>/mason/bin` on PATH, and rustaceanvim resolves `rust-analyzer`
  -- through PATH when it starts the client. Rust is deliberately absent from
  -- `ucw.lsp.servers`, so opening a .rs file loads no nvim-lspconfig and
  -- nothing else here would pull mason in.
  --
  -- It worked anyway until now, by accident: rustaceanvim happens to
  -- `require('mason-registry')` while probing for a codelldb DAP adapter
  -- (config/internal.lua), and lazy.nvim loads mason.nvim off that require.
  -- Measured - lazy's own record was
  -- `mason.nvim = { require = "mason-registry", source = ".../rustaceanvim/..." }`.
  -- Without mason's PATH, rustaceanvim starts *no client at all* and says
  -- nothing: not in `:messages`, not in `lsp.log` (Phase 3 acceptance review,
  -- P4). Declaring it costs nothing - mason is `ft`-loaded either way.
  dependencies = { 'williamboman/mason.nvim' },
  init = function()
    -- rustaceanvim's client is named `rust-analyzer`, with a hyphen. The old
    -- hook filtered on `rust_analyzer` and so never matched it: this keymap
    -- only ever existed because the duplicate mason-started client (which does
    -- use an underscore) happened to match. Removing the duplicate would have
    -- silently removed the keymap with it - tests/test_lsp.lua guards that.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('ucw.lsp.rust', { clear = true }),
      desc = 'ucw: rust-analyzer grouped code actions',
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= 'rust-analyzer' then
          return
        end
        vim.keymap.set('n', '<leader>a', function()
          vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
        end, { silent = true, buffer = args.buf, desc = 'Code actions (rust-analyzer groups)' })
      end,
    })

    vim.g.rustaceanvim = {
      tools = {},
      server = {
        -- `.vscode/settings.json` is handled for every client by
        -- ucw.lsp.vscode on LspAttach, including this one; letting
        -- rustaceanvim load it too would apply the same file twice through
        -- two different code paths.
        load_vscode_settings = false,
        default_settings = {
          ['rust-analyzer'] = {
            -- folded in from the old lsp/lang/rust_analyzer.lua, which never
            -- ran: rust-analyzer never went through lspconfig. It spelled this
            -- `checkOnSave.command = 'clippy'`; rust-analyzer split that into a
            -- boolean `checkOnSave` plus `check.command`.
            checkOnSave = true,
            check = { command = 'clippy' },
          },
        },
      },
      dap = {},
    }
  end,
}
