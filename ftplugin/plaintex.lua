-- Block conform's LSP fallback: texlab attaches here too (ucw.lsp.servers)
-- and advertises formatting, so without this every `format_on_save` write
-- would reformat the file through it. Same override as ftplugin/tex.lua.
require('conform').formatters_by_ft.plaintex = { lsp_format = 'never' }
