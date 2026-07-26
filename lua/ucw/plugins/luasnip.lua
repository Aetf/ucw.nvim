local au = require('au')

return {
  'L3MON4D3/LuaSnip',
  lazy = false,
  dependencies = { 'rafamadriz/friendly-snippets' },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
    local luasnip = require("luasnip")
    -- disable diagnostic when in snippet
    au.group('luasnip-expand', {
      { 'ModeChanged', '*:s"', function()
        if luasnip.in_snippet() then
          return vim.diagnostic.disable()
        end
      end },
      { 'ModeChanged', '[is]:n', function()
        if luasnip.in_snippet() then
          return vim.diagnostic.enable()
        end
      end }
    })
  end,
}
