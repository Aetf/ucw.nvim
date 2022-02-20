local M = {}

M.url = 'onsails/lspkind-nvim'
M.description = 'Vscode-like pictograms for neovim lsp completion items'

M.requires = {
  'nvim-cmp',
}
M.after = {
  'nvim-cmp',
}

-- configs
local function format_item(entry, vim_item)
  local alias = {
    buffer = "buffer",
    path = "path",
    nvim_lsp = "LSP",
    luasnip = "LuaSnip",
    nvim_lua = "Lua",
    latex_symbols = "Latex",
  }

  if entry.source.name == "nvim_lsp" then
    vim_item.menu = entry.source.source.client.name
  else
    vim_item.menu = alias[entry.source.name] or entry.source.name
  end
  return vim_item
end

function M.config()
  local cmp = require('cmp')
  local lspkind = require('lspkind')
  cmp.setup {
    formatting = {
        format = lspkind.cmp_format{
        mode = 'symbol_text',
        maxwidth = 50,
        before = format_item,
      },
    },
  }
end

return M
