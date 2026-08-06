-- No `lsp_format` override: unlike `lua_ls`, the LSP fallback client here
-- (`ruff`) is the same tool `ruff_format` shells out to, so falling back to
-- it if the named formatter were ever unavailable reaches the right tool
-- anyway, not a trap.
require('conform').formatters_by_ft.python = { 'ruff_format' }
