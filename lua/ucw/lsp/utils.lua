-- `lazy_root_pattern` used to live here: it wrapped `lspconfig.util.root_pattern`
-- so root detection could be deferred and could opt buffers out by buftype.
-- Native `root_markers` covers the same ground declaratively, and requiring
-- `lspconfig.util` is exactly the thing Phase 3 stopped doing - nvim-lspconfig
-- is a passive registry now, never a library.

local Path = require('plenary.path')
local F = vim.fn

local M = {}

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
--
-- Reads `client.workspace_folders`, not `client.config.workspace_folders`. The
-- latter is what this used to say and it is always nil on Neovim 0.12 - the
-- folders are computed during client creation and live on the client, not on
-- the config it was built from. The failure was silent and plausible-looking:
-- ltex kept writing dictionary entries to the global store instead of the
-- project's `.vscode/`, which just looks like "the word was added" until you
-- open the project somewhere else.
---@param client vim.lsp.Client
---@param doc_uri string
---@return Path?
function M.locate_root_for_doc(client, doc_uri)
  local doc = Path:new(vim.uri_to_fname(doc_uri))
  local roots = client.workspace_folders
  if not roots or #roots == 0 then
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
