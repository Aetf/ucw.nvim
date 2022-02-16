local M = {}

M.url = 'jose-elias-alvarez/null-ls.nvim'
M.description = 'Hook non-LSP sources to nvim LSP framework'

M.requires = {
  'plenary'
}
M.after = {
  'plenary'
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.lsp'
  }
}

function M.config()
  local nl = require('null-ls')
  nl.setup {
    sources = {
      -- nl.builtins.formatting.isort,
      -- nl.builtins.formatting.yapf,
      -- nl.builtins.formatting.autopep8,
      nl.builtins.formatting.black,

      -- nl.builtins.diagnostics.flake8,
      -- nl.builtins.diagnostics.pylint,

      nl.builtins.formatting.stylua,

      -- nl.builtins.diagnostics.luacheck,
      -- nl.builtins.formatting.lua_format,

      -- nl.builtins.formatting.prettier,

      -- nl.builtins.formatting.shfmt,
      -- nl.builtins.diagnostics.shellcheck,

      nl.builtins.diagnostics.chktex,

      -- nl.builtins.diagnostics.cppcheck,

      nl.builtins.code_actions.gitsigns,

      -- nl.builtins.code_actions.refactoring,
    }
  }
end

return M
