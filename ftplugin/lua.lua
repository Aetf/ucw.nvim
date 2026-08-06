-- `lsp_format = 'never'` is load-bearing, not decoration: `lua_ls` also
-- advertises `documentFormattingProvider`, with its own EmmyLua-style
-- formatter that does not read `stylua.toml`. Without this override,
-- conform.lua's `default_format_opts.lsp_format = 'fallback'` would silently
-- defer to `lua_ls` whenever `stylua` isn't on PATH yet (e.g. before
-- mason-tool-installer finishes) instead of failing loudly.
-- See docs/design/phase6-format-lint.md §1.1.
require('conform').formatters_by_ft.lua = { 'stylua', lsp_format = 'never' }
