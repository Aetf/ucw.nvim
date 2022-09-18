-- FUTURE: remove this once nvim 0.8 is released.
-- The issue [1] was fixed but not released yet.
-- [1]: https://github.com/neovim/neovim/issues/12587

---@type nvimd.Unit
local M = {}

M.url = 'antoinemadec/FixCursorHold.nvim'
M.description = 'Fix slowness in CursorHold'

M.no_default_dependencies = true
M.activation = {
  wanted_by = {
    'target.base',
  },
}

function M.config()
  -- in ms
  vim.g.cursorhold_updatetime = 100
end

return M
