local M = {}

M.url = 'windwp/nvim-autopairs'
M.description = 'Insert parenthesis'

M.wants = {
  'nvim-cmp'
}

M.after = {
  'nvim-cmp'
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.completion'
  }
}

function M.config()
  require('nvim-autopairs').setup{
    check_ts = true,
    enable_check_bracket_line = true,
  }
  local cmp_autopairs = require('nvim-autopairs.completion.cmp')

  local with_cmp, cmp = pcall(require, 'cmp')
  if with_cmp then
    cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done({}))
  end
end


return M
