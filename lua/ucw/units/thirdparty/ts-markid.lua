local M = {}

M.url = 'David-Kunz/markid'
M.description = 'highlight same-name identifiers with the same color.'
-- Disable for now due to error on bufdelete
M.disabled = true

M.after = {
  'treesitter',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'treesitter'
  }
}

return M
