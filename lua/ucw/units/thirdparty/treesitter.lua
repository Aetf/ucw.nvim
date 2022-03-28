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
    },

    -- text objects
    textobjects = {
      select = {
        enable = true,
        -- automatically jump forward to textobj, similar to targets.vim
        lookahead = true,
        keymaps = {
          ['ab'] = '@block.outer',
          ['ib'] = '@block.inner',
          ['af'] = '@function.outer',
          ['if'] = '@function.inner',
        }
      },
      move = {
        enable = true,
        -- whether to set jumps in the jumplist
        set_jumps = true,
        goto_next_start = {
          [']m'] = '@function.outer',
          [']['] = '@class.outer',
        },
        goto_next_end = {
          [']M'] = '@function.outer',
          [']]'] = 'class.outer',
        },
        goto_previous_start = {
          ['[m'] = '@function.outer',
          ['[['] = '@class.outer',
        },
        goto_previous_end = {
          ['[M'] = '@function.outer',
          ['[]'] = '@class.outer',
        }
      },
      lsp_interop = {
        enable = true,
        border = 'none',
        peak_definition_code = {
          ['<leader>lpf'] = '@funciton.outer',
          ['<leader>lpc'] = '@class.outer',
        }
      }
    }
  }

  -- code folding
  vim.opt.foldmethod = 'expr'
  vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'
end

return M
