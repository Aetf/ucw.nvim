local M = {}

M.url = 'nvim-treesitter/nvim-treesitter'
M.description = 'Treesitter does syntax and folding'

M.run = function()
  vim.cmd 'TSUpdate'
end

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  require('nvim-treesitter.configs').setup {
    -- set of languages to install
    ensure_installed = 'maintained',
    -- async language installation
    sync_install = false,
    -- list of parsers to ignore installing
    ignore_install = {},

    -- modules

    -- consistent syntax highlighting
    highlight = {
      enable = true,
    },

    -- indentation based on treesitter for the `=` operator
    indent = {
      enable = true,
    },

    -- accurate commentstring
    context_commentstring = {
      enable = true,
      -- commentstring update will be handled by the actual commenting plugin
      enable_autocmd = false,
    },

    -- rainbow parenthesis
    rainbow = {
      enable = true,
    }
  }

  -- code folding
  vim.opt.foldmethod = 'expr'
  vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'
end

return M
