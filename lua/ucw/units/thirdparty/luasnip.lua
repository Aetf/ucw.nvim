local M = {}

M.url = 'L3MON4D3/LuaSnip'
M.description = 'Snips'

M.wants = {
  'cmp_luasnip',
  'friendly-snippets',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.completion'
  }
}

function M.config()
  require("luasnip.loaders.from_vscode").load()
end

return M
