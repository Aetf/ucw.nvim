-- No `formatters_by_ft` here - that lives per filetype in `ftplugin/<ft>.lua`
-- (`require('conform').formatters_by_ft.<ft> = ...`), next to that filetype's
-- other settings, the same convention `ftplugin/tex.lua` and
-- `ftplugin/just.lua` already use for buffer-local options. Safe regardless of
-- load order because conform is `lazy = false` below, so it is always loaded
-- before any buffer's `ftplugin` runs; conform itself reads `formatters_by_ft`
-- fresh on every format call, not a value captured at `setup()` time.
-- See docs/design/phase6-format-lint.md §2a/§3.
--
-- `lazy = false` rather than gating on `event`/`cmd`/`ft`: measured at ~0.16ms
-- to load (0.03ms sourcing `plugin/conform.lua`, 0.13ms `require('conform')`),
-- smaller than this config's own run-to-run startup jitter. There is also no
-- lazy trigger that would actually keep it unloaded in practice - any
-- `ftplugin/<ft>.lua` calling `require('conform')` forces lazy.nvim to load it
-- immediately regardless of a declared trigger (same mechanism documented in
-- `lua/ucw/plugins/rustaceanvim.lua`'s `mason-registry` comment).
--
-- No `cond = is_full_ui`, unlike lspconfig.lua/mason-lspconfig.lua: conform
-- has no UI surface of its own to gate (it shells out to CLI formatters or
-- falls back to whatever LSP client is already attached), so there is
-- nothing about firenvim/vscode-neovim it needs to avoid. Gating it the same
-- way as the LSP stack turned `<leader>lf`'s `fn` action kind (which
-- `require()`s its target by name and errors if that fails, on purpose - see
-- lua/ucw/lsp/actions.lua) into a hard "module 'conform' not found" crash
-- under those two targets, in place of the graceful "no formatters
-- available" conform already gives everywhere else. See
-- docs/design/phase6-acceptance-review.md R1.
return {
  'stevearc/conform.nvim',
  lazy = false,
  opts = {
    -- Conform's own default is `lsp_format = 'never'`: a filetype with no
    -- `formatters_by_ft` entry and no override gets no formatting at all,
    -- which would regress `<leader>lf` for every filetype this phase didn't
    -- touch (clangd, ltex, rust-analyzer, ...) versus today's
    -- `vim.lsp.buf.format()`, which reaches whatever attached client offers
    -- it. `'fallback'` (try LSP only when no formatter is configured) keeps
    -- that reach. Filetypes that need this blocked (lua_ls's own formatter
    -- vs. stylua; texlab's vs. this config's hand-tuned tex `formatexpr`)
    -- override it locally in their own `ftplugin/<ft>.lua` entry - see
    -- docs/design/phase6-format-lint.md §1.1/§1.5 for why both are real
    -- traps, not hypothetical ones.
    default_format_opts = {
      lsp_format = 'fallback',
    },
    -- Deliberately no `lsp_format` override here: it would be call-site opts,
    -- which conform resolves *before* any `formatters_by_ft`-level override,
    -- so a blanket value here would silently overrule every per-filetype
    -- decision at once - e.g. `'never'` would also turn off Rust's fallback
    -- to rust-analyzer, which this phase does not want to touch. See
    -- docs/design/phase6-format-lint.md §2 D2.
    format_on_save = {
      timeout_ms = 500,
    },
  },
}
