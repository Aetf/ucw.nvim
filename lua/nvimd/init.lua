local nvimctl = require('nvimd.nvimctl')
local M = {}

---@class nvimd.SetupOptions
---@field units_modules string[]

---@param opts nvimd.SetupOptions
---@return nvimd.nvimctl
function M.setup(opts)
  return nvimctl.new(opts.units_modules)
end

return M
