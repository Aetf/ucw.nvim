local Path = require('plenary.path')
local F = vim.fn

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

---@param parent Path
---@param path Path
---@return boolean
function M.dir_contains_path(parent, path)
  local parent_str = F.fnamemodify(parent.filename, ':p')
  local path_str = F.fnamemodify(path.filename, ':p')

  local prefix_pattern = '^' .. vim.pesc(parent_str)
  return path_str:find(prefix_pattern) ~= nil
end

-- Locate a root dir for uri, or return nil if in single file mode
---@param client any
---@param doc_uri string
---@return Path?
function M.locate_root_for_doc(client, doc_uri)
  local doc = Path:new(vim.uri_to_fname(doc_uri))
  local roots = client.config.workspace_folders
  if not roots then
    return
  end

  local root = Path:new(vim.uri_to_fname(roots[1].uri))
  for _, wsp in pairs(roots) do
    local parent = Path:new(vim.uri_to_fname(wsp.uri))
    if M.dir_contains_path(parent, doc) then
      root = parent
    end
  end
  return root
end

return M
