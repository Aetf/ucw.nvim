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
  for _, units_module in pairs(self.units_modules) do
    utils.reload(units_module)
  end
end

---@class nvimd.Unit
---@field disabled? boolean
---@field loaded boolean
---@field name string
---@field url string
---@field run? string|fun()
---@field description string
---@field requires string[] Similar to wants, but declares a stronger requirement dependency.
---@field wants string[] Configures (weak) requirement dependencies on other units.
---@field requisite string[] Similar to requires. However, if the units listed here are not started already, they will not be started and the starting of this unit will fail immediately.
---@field before string[]
---@field after string[]
---@field activation.cmd string|string[]
---@field activation.wanted_by string[]
---@field activation.required_by string[]
---@field activation.requisite_of string[]
---@field pack_name? string The name used for packadd
---@field config? fun() Optional config function
---@field config_source? string Where the config function was last defined
---@field sources string[] Where this unit is defined
---@field started boolean
---@field after_files string[]
---@field triggers nvimd.Trigger[]

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
  run = nil,
  description = '',

  config = nil,

  requires = {},
  wants = {},

  before = {},
  after = {},

  activation = {
    cmd = {},
    wanted_by = {},
    required_by = {},
  },

  pack_name = nil,
  config_source = nil,
  triggers = {},

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
  local errors = {}
  local notfound_errors = {}
  -- try load it, note that we do not break, but merge all units with the same name
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
      loaded.triggers = nil

      -- start from existing unit, merging in any existing
      unit = utils.merge(unit, loaded)
      unit.name = name
      unit.loaded = true
      if loaded.config then
        unit.config_source = unit_module
      end
      table.insert(unit.sources, unit_module)
    elseif string.find(loaded, 'E5108') then -- module not found
      table.insert(notfound_errors, { unit_module, loaded })
    else -- other errors
      table.insert(errors, { unit_module, loaded })
    end
  end
  if found then
    self.units[name] = unit
    return unit
  elseif #errors > 0 then
    return nil, errors
  else
    return nil, notfound_errors
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
  -- set its pack name, we override this when installing so its always the same as name
  if unit.url and unit.url ~= "" then
    unit.pack_name = unit.name
  end

  -- normalize a few types
  if type(unit.activation.cmd) == 'string' then
    unit.activation.cmd = {unit.activation.cmd}
  end

  -- resolve all bidirectional edges
  local function load(name)
    return self:load_unit(name)
  end

  utils.bidi_edge(unit, 'wants', 'activation.wanted_by', load)
  utils.bidi_edge(unit, 'activation.wanted_by', 'wants', load)

  utils.bidi_edge(unit, 'requires', 'activation.required_by', load)
  utils.bidi_edge(unit, 'activation.required_by', 'requires', load)

  utils.bidi_edge(unit, 'requisite', 'activation.requisite_of', load)
  utils.bidi_edge(unit, 'activation.requisite_of', 'requisite', load)

  utils.bidi_edge(unit, 'before', 'after', load)
  utils.bidi_edge(unit, 'after', 'before', load)
end

return resolver
