local M = {}

M.url = 'lukas-reineke/cmp-under-comparator'
M.description = 'nvim-cmp comparator that respects underline'

M.requires = {
  'nvim-cmp'
}

M.after = {
  'nvim-cmp',
}

function M.config()
  local cmp = require('cmp')
  -- multiple setup calls will merge the config
  cmp.setup {
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,
      require "cmp-under-comparator".under,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  }
end

return M
