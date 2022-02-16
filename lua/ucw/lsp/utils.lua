local M = {}

-- Lazy load lspconfig, then do file matching on resolved path
function M.lazy_root_pattern(...)
  local lsp_util = require('lspconfig.util')
  local matcher = lsp_util.root_pattern(...)

  return function(fname)
    fname = vim.fn.fnamemodify(fname, ':p')
    return matcher(fname)
  end
end

return M
