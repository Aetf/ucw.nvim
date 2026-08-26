-- No `lsp_format` override: the LSP fallback client here (`taplo`) is the
-- same binary `taplo` shells out to, same reasoning as ftplugin/python.lua.
require('conform').formatters_by_ft.toml = { 'taplo' }
