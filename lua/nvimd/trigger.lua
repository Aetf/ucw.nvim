local M = {}
local log = require('nvimd.utils.log')
local utils = require('nvimd.utils')

local counter = 0
local function gen_global_name()
    counter = counter + 1
    return string.format('__nvimd_global_%d', counter)
end

---@class nvimd.Trigger
---@field activated boolean
---@field global string necessary global states
---@field nvimctl nvimd.nvimctl
---@field unit_name string
---@field cmds string[]
local Trigger = {}

function Trigger.new(unit_name, nvimctl)
  local self = setmetatable({}, { __index = Trigger })

  self.activated = false
  self.global = gen_global_name()
  _G[self.global] = self

  self.unit_name = unit_name
  self.nvimctl = nvimctl

  self.cmds = {}

  return self
end

---@param cause.cmd? string
---@param cause.l1? string
---@param cause.l2? string
---@param cause.mods? string
---@param cause.bang? string
---@param cause.args? string
function Trigger:trigger(cause)
    self:remove()

    if self.activated then
        return
    end

    self.activated = true

    self.nvimctl:start(self.unit_name)

    if cause.cmd then
        local lines = cause.l1 == cause.l2 and '' or (cause.l1 .. ',' .. cause.l2)
        vim.cmd(string.format('%s %s%s%s %s', cause.mods or '', lines, cause.cmd, cause.bang, cause.args))
    end
end

function Trigger:remove()
    if self.activated then
        return
    end
    for _, cmd in pairs(self.cmds) do
        vim.cmd([[delcommand! ]] .. cmd)
    end
    if self.global then
        _G[self.global] = nil
    end
end

---@param cmds string[]
function Trigger:arm_cmds(cmds)
    for _, cmd in pairs(cmds) do
        table.insert(self.cmds, cmd)
        vim.cmd(string.format([[command! -nargs=* -range -bang %s lua %s:trigger({ cmd = "%s", l1 = <line1>, l2 = <line2>, bang = <q-bang>, args = <q-args>, mods = "<mods>" })]], cmd, self.global, cmd))
    end
end

---@param cmds string[]
---@param unit_name string
---@return nvimd.Trigger
function M.add_cmds(cmds, unit_name, nvimctl)
    local t = Trigger.new(unit_name, nvimctl)
    t:arm_cmds(cmds)
    return t
end

return M
