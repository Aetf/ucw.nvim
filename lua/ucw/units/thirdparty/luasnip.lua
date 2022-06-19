local M = {}

M.url = 'L3MON4D3/LuaSnip'
M.description = 'Snips'

M.wants = {
  'friendly-snippets',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.completion'
  }
}

local au = require('au')

function M.config()
  require("luasnip.loaders.from_vscode").load()
  local luaship = require("luasnip")
  -- disable diagnostic when in snippet
  au.group('luaship-expand', {
    { 'ModeChanged', '*:s"', function()
      if luaship.in_snippet() then
        return vim.diagnostic.disable()
      end
    end },
    { 'ModeChanged', '[is]:n', function()
      if luaship.in_snippet() then
        return vim.diagnostic.enable()
      end
    end }
  })
end

return M
