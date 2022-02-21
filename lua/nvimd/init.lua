local F = vim.fn

local nvimctl = require('nvimd.nvimctl')
local utils = require('nvimd.utils')

local M = {}

---@class nvimd.SetupOptions
---@field units_modules string[]

---load packages and run their config functions from a compiled file.
---if the compiled file is not found, this simply returns false.
---in that case, just call nvimctl:sync and try boot again.
---@param opts nvimd.SetupOptions
---@param target string
function M.boot(opts, target)
  local compiled_target = 'nvimd.compiled.' .. target
  local present, compiled = pcall(require, compiled_target)
  if present then
    compiled()
  else
    local ctl = nvimctl.new(opts.units_modules)

    utils.log.warn('New install, bootstraping')

    ctl:sync(function()
      ctl:compile(target)
      ctl:start(target)
    end)
  end
end

return M
