local M = {}

M.url = 'nvim-treesitter/nvim-treesitter'
M.description = 'Treesitter does syntax and folding'

M.run = function()
  local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
  ts_update()
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
    ensure_installed = {
      'bash',
      'beancount',
      'bibtex',
      'c', 'c_sharp', 'cmake',
      'comment', -- for todo, fixme, etc
      'cpp',
      'css',
      'cuda',
      'dart',
      'dockerfile',
      'dot',
      'fennel',
      'fish',
      'glsl',
      'go',
      'hjson',
      'html',
      'java',
      'javascript',
      'jsdoc',
      'json',
      'json5',
      'jsonc',
      'latex',
      'llvm',
      'lua',
      'make',
      'markdown',
      'ninja',
      'nix',
      'norg',
      'perl',
      'php',
      'pug',
      'python',
      'regex',
      'rst',
      'ruby',
      'rust',
      'scss',
      'toml',
      'tsx',
      'typescript',
      'vim',
      'vimdoc', -- vim help files
      'vue',
      'yaml',
    },
    -- async language installation
    sync_install = false,

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

    -- markid
    markid = {
      enable = true,
    },

    -- text objects
    textobjects = {
      -- only provides ts query, text object exposed via mini-ai
      select = {
        enable = false,
      },
      move = {
        enable = false,
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
  ---WORKAROUND for No folds found error
  -- See https://github.com/nvim-treesitter/nvim-treesitter/wiki/Installation#packernvim
  vim.api.nvim_create_autocmd({'BufEnter','BufAdd','BufNew','BufNewFile','BufWinEnter'}, {
    group = vim.api.nvim_create_augroup('TS_FOLD_WORKAROUND', {}),
    callback = function()
      vim.opt.foldmethod     = 'expr'
      vim.opt.foldexpr       = 'nvim_treesitter#foldexpr()'
    end
  })
  ---ENDWORKAROUND

  -- Additional parser
  require("nvim-treesitter.parsers").get_parser_configs().just = {
    install_info = {
      url = "https://github.com/IndianBoy42/tree-sitter-just",
      files = { "src/parser.c", "src/scanner.cc" },
      branch = "main",
    },
    maintainers = { "@IndianBoy42" },
  }
end

return M
