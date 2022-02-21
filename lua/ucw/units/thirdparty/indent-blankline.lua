local M = {}

M.url = 'lukas-reineke/indent-blankline.nvim'
M.description = 'Show indentation guide'

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('indent_blankline').setup {
    show_trailing_blankline_indent = false,
    show_current_context = true,
    show_current_context_start = true,
    filetype_exclude = {
      'lspinfo',
      'packer',
      'checkhealth',
      'help',
      '',
      'neo-tree'
    },
  }
end

return M
