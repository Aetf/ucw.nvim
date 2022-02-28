local M = {}

local disabled_buftypes = {
  'help',
}

-- Lazy load lspconfig, then do file matching on resolved path
function M.lazy_root_pattern(...)
  local lsp_util = require('lspconfig.util')
  local matcher = lsp_util.root_pattern(...)

  return function(fname, bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    if vim.tbl_contains(disabled_buftypes, buftype) then
      -- lspconfig may enable single file support if return nil,
      -- so we just return an invalid path
      return '/non-exists'
    end
    fname = vim.fn.fnamemodify(fname, ':p')
    return matcher(fname)
  end
end

return M
