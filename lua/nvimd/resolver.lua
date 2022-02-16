local L = vim.loop
local F = vim.fn
local A = vim.api
local utils = require('nvimd.utils')

---@class nvimd.resolver
---@field units_modules string[]
---@field units table<string, nvimd.Unit>
local resolver = {}


---Create a new unit resolver instance. If a name is found at multiple locations, all of them is required,
---with later overwriting fields in earlier ones.
---@param units_modules string[], list of module names containing modules
---@return nvimd.resolver
function resolver.new(units_modules)
  local self = setmetatable({}, { __index = resolver })

  self.units_modules = {unpack(units_modules)}
  table.insert(self.units_modules, 1, 'nvimd.units')
  self.units = {}

  return self
end

function resolver:reset()
  self.units = {}
  -- Clear lua module cache
  -- also Handle impatient.nvim automatically.
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache
  for module, _ in pairs(package.loaded) do
    for _, units_module in pairs(self.units_modules) do
      if string.find(module, '^' .. vim.pesc(units_module) .. '%.') then
        package.loaded[module] = nil
        if luacache then
          luacache[module] = nil
        end
      end
    end
  end
end

---@class nvimd.Unit
---@field disabled? boolean
---@field loaded boolean
---@field started boolean
---@field name string
---@field url string
---@field description string
---@field requires string[]
---@field wants string[]
---@field before string[]
---@field after string[]
---@field activation.cmd string|string[]
---@field activation.module string
---@field activation.wanted_by string[]
---@field activation.required_by string[]
---@field pack_name? string The name used for packadd
---@field config? fun() Optional config function
---@field sources string[] Where this unit is defined

---@type nvimd.Unit
local default_unit = {
  -- disabled units will not be installed
  disabled = nil,
  -- used during unit reloading
  loaded = false,
  -- set to true when the plugin is actually loaded
  started = false,

  name = '',
  url = '',
  description = '',

  requires = {},
  wants = {},

  before = {},
  after = {},

  activation = {
    cmd = {},
    module = {},
    wanted_by = {},
    required_by = {},
  },

  pack_name = nil,
  config = nil,

  sources = {}
}

-- find and require a unit module
---@param name string
---@return nvimd.Unit?
function resolver:load_unit(name)
  if self.units[name] and self.units[name].loaded then
    return self.units[name]
  end

  -- do a merge here to always deep copy the default unit
  local unit = self.units[name] or utils.deepcopy(default_unit)
  local found = false
  -- try load it, not that we do not break
  for _, parent in pairs(self.units_modules) do
    local unit_module = parent .. '.' .. name
    local present, loaded = pcall(require, unit_module)
    if present then
      found = true
      -- sanitize on loaded unit
      -- only trust compiled unit
      if parent ~= 'nvimd.compiled' then
        loaded.sources = nil
        loaded.started = nil
      end

      -- start from existing unit, merging in any existing
      unit = utils.merge(unit, loaded)
      unit.name = name
      unit.loaded = true
      table.insert(unit.sources, unit_module)
    end
  end
  if found then
    self.units[name] = unit
    return unit
  else
    return nil
  end
end

-- list all module names in candidates, with parent as the root module
local function units_in_directory(path, candidates, parent)
  if not parent then
    parent = ''
  end
  local handle = vim.loop.fs_scandir(path)
  if handle then
    while true do
      local name, typ = L.fs_scandir_next(handle)
      if not name then
        break
      end
      name = F.fnamemodify(name, ':t:r')
      if name == 'target' and typ == 'directory' then
        if parent == '' then
          units_in_directory(path .. '/' .. name, candidates, name .. '.')
        end
      elseif typ == 'file' then
        table.insert(candidates, parent .. name)
      end
    end
  end
end

---emulate the lua module loading process, but not actually load file module.
---only the dir path is returned
function resolver:discover_units()
  local candidates = {}

  for _, units_module in pairs(self.units_modules) do
    -- convert dot to path sep
    units_module = string.gsub(units_module, '%.', '/')

    -- try to find the module dir on runtimepath
    for _, path in pairs(A.nvim_get_runtime_file('lua/' .. units_module, false)) do
      units_in_directory(path, candidates)
    end
  end
  return candidates
end

-- resolve the unit, install its' wanted_by activations to target's wants array
---@param unit nvimd.Unit
function resolver:resolve_unit(unit)
  if not unit.loaded then
    return
  end
  assert(unit.name and unit.name ~= "", "Invalid unit name")
  if unit.url and unit.url ~= "" then
    unit.pack_name = F.fnamemodify(unit.url, ':t')
  end
  -- set its pack name, usually this is the git clone folder name
  -- wants and wanted_by
  for _, want in pairs(unit.wants) do
    local target_unit = self:load_unit(want)
    if target_unit and not vim.tbl_contains(target_unit.activation.wanted_by, unit.name) then
      table.insert(target_unit.activation.wanted_by, unit.name)
    end
  end
  for _, wanted_by in pairs(unit.activation.wanted_by) do
    local target_unit = self:load_unit(wanted_by)
    if target_unit and not vim.tbl_contains(target_unit.wants, unit.name) then
      table.insert(target_unit.wants, unit.name)
    end
  end
  -- requires and required_by
  for _, v in pairs(unit.requires) do
    local target_unit = self:load_unit(v)
    if target_unit and not vim.tbl_contains(target_unit.activation.required_by, unit.name) then
      table.insert(target_unit.activation.required_by, unit.name)
    end
  end
  for _, required_by in pairs(unit.activation.required_by) do
    local target_unit = self:load_unit(required_by)
    if target_unit and not vim.tbl_contains(target_unit.requires, unit.name) then
      table.insert(target_unit.requires, unit.name)
    end
  end
  -- before and after
  for _, v in pairs(unit.before) do
    local target_unit = self:load_unit(v)
    if target_unit and not vim.tbl_contains(target_unit.after, unit.name) then
      table.insert(target_unit.after, unit.name)
    end
  end
  for _, v in pairs(unit.after) do
    local target_unit = self:load_unit(v)
    if target_unit and not vim.tbl_contains(target_unit.before, unit.name) then
      table.insert(target_unit.before, unit.name)
    end
  end
end

return resolver
