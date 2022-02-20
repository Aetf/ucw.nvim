local F = vim.fn
local au = require('au')

local nvimctl = require('nvimd.nvimctl')

local M = {}

---@class nvimd.SetupOptions
---@field units_modules string[]

---Get compiled path for target
local function compiled_path(target)
  target = string.gsub(target, '%.', '/')
  return F.stdpath('data') .. '/site/lua/nvimd/compiled/' .. target .. '.lua'
end

---load packages and run their config functions from a compiled file.
---if the compiled file is not found, this simply returns false.
---in that case, just call nvimctl:sync and try boot again.
---@param opts nvimd.SetupOptions
---@param target string
function M.boot(opts, target)
  local present, compiled = pcall(require, 'nvimd.compiled.' .. target)
  if present then
    compiled()
  else
    local ctl = nvimctl.new(opts.units_modules)
    local function start_and_compile()
      ctl:start(target)
      _G.nvimctl = ctl
      ctl:compile(target, compiled_path(target))
    end

    au.User = {
      'PaqDoneSync',
      start_and_compile,
      once = true
    }
    ctl:sync()
  end
end

return M
