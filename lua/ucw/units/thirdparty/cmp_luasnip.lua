local M = {}

M.url = 'saadparwaiz1/cmp_luasnip'
M.description = 'Provide luasnip as a source to nvim-cmp'

-- If there's no nvim-cmp, no need to load this
M.requisite = {
  'nvim-cmp',
  'luasnip',
}
M.after = {
  'nvim-cmp'
}

M.activation = {
  wanted_by = {
    'luasnip',
    'nvim-cmp',
  }
}

function M.config()
  local cmp = require('cmp')
  cmp.setup {
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      end,
    },
  }
end

return M
