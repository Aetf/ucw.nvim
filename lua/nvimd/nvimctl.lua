---@diagnostic disable-next-line: unused-local
local L = vim.loop
---@diagnostic disable-next-line: unused-local
local F = vim.fn
---@diagnostic disable-next-line: unused-local
local A = vim.api

---@diagnostic disable-next-line: unused-local
local utils = require('nvimd.utils')
local resolver = require('nvimd.resolver')
local trigger = require('nvimd.trigger')
local txn = require('nvimd.txn')
local log = require('nvimd.utils.log')


---@class nvimd.nvimctl
---@field resolver nvimd.resolver
---@field graph table<string, nvimd.UnitNode>
---@field triggers nvimd.Trigger[]
local nvimctl = {}

---Create a new nvimctl instance. If a name is found at multiple locations, all of them is required,
---with later overwriting fields in earlier ones.
---@param units_modules string[], list of module names containing modules
---@return nvimd.nvimctl
function nvimctl.new(units_modules)
  local self = setmetatable({}, { __index = nvimctl })

  self.resolver = resolver.new(units_modules)

  self.graph = {}
  self.triggers = {}

  self:reload()

  return self
end

---@param unit_name string
function nvimctl:enable(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  unit.disabled = false
end

---@param unit_name string
function nvimctl:disable(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  unit.disabled = true
end

---@param unit_name string
---@return boolean
function nvimctl:is_disabled(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  return unit.disabled
end

---@param unit_name string
function nvimctl:status(unit_name)
  local unit, errors = self.resolver:load_unit(unit_name)
  if unit then
    print(vim.inspect(unit))
  else
    local formatted = {}
    for _, info in pairs(errors) do
      local unit_module, err = unpack(info)
      err = string.gsub(err, '(\n\t*)', '%1\t')
      table.insert(formatted, string.format('\nFailed to load from %s.%s:\n\t%s', unit_module, unit_name, err))
    end
    error(table.concat(formatted))
  end
end

---start a unit as well as any dependencies
---@param unit_name string
function nvimctl:start(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  if unit.started then
    return
  end

  return txn.do_transaction(unit_name, self.resolver, function(name)
    return self:activate(name)
  end, function(u) return not u.started end)
end

-- actually activate the package and run its config function
---@param unit_name string
---@return nvimd.Unit
function nvimctl:activate(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  if not unit then
    return
  end
  if unit.started then
    return unit
  end
  unit.started = true

  if unit.pack_name then
    require('nvimd.utils.log').info('Activating', unit.name, 'pack', unit.pack_name)
    local cmd = string.format('packadd %s', unit.pack_name)
    local ok, err_msg = pcall(vim.cmd, cmd)
    if not ok then
      require('nvimd.utils.log').error('Failed to activate', unit.name, err_msg)
      return
    end
  end
  if unit.config then
    local ok, err_msg = pcall(unit.config)
    if not ok then
      require('nvimd.utils.log').error('Failed to activate', unit.name, err_msg)
      return
    end
    require('nvimd.utils.log').info('Configuring', unit.name)
  end
  require('nvimd.utils.log').info('Activated', unit.name)

  return unit
end

---compile a startup file that does the package loading to reach the
---target without a -nvimctl instance. The actual instance creation is
---done later in async
---@param target string
---@param path string
function nvimctl:compile(target, path)
  assert(self.resolver:load_unit(target) ~= nil, "Nonexisting unit " .. target)

  local started_units = {}
  local compiled = {}

  table.insert(compiled, [[return function()]])

  txn.do_transaction(target, self.resolver, function(name)
    local unit = self.resolver:load_unit(name)

    table.insert(started_units, unit.name)

    if unit.pack_name then
      table.insert(compiled, string.format([[  vim.cmd("packadd %s")]], unit.pack_name))
    end
    if unit.config and unit.config_source then
      table.insert(compiled, string.format([[  require("%s").config()]], unit.config_source))
    end

    return unit
  end)

  -- do a full reload after initialization
  table.insert(compiled, string.format([[
  require('au').CursorHold = {
    '*',
    once = true,
    function()
      vim.schedule(function()
        _G.nvimctl = require('nvimd.nvimctl').new(%s)
        for _, name in pairs(%s) do
          _G.nvimctl.resolver.units[name].started = true
        end
      end)
    end
  }
  ]],
    vim.inspect(self.resolver.units_modules),
    vim.inspect(started_units)
  ))

  table.insert(compiled, [[end]])

  path = vim.fn.expand(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local file = io.open(path, 'w')
  file:write(table.concat(compiled, '\n'))
  file:close()
end

---generate paq.vim spec and call PackerSync to install and compile file
function nvimctl:sync()
  self:reload()
  local paq = require('nvimd.boot').paq()
  local pkgs = {
    {'savq/paq-nvim'},
  }
  for _, unit in pairs(self.resolver.units) do
    if unit.url and unit.url ~= "" then
      if string.find(unit.url, [[://]]) then
        table.insert(pkgs, {
          url = unit.url,
          run = unit.run,
          opt = true,
        })
      else
        table.insert(pkgs, {
          unit.url,
          run = unit.run,
          opt = true,
        })
      end
    end
  end
  paq(pkgs)
  paq:sync()
end

---reload all units
function nvimctl:reload()
  self.graph = {}

  for _, t in pairs(self.triggers) do
    t:remove()
  end
  self.triggers = {}

  local r = self.resolver
  r:reset()

  local cands = r:discover_units()
  for _, unit_name in pairs(cands) do
    r:load_unit(unit_name)
  end
  -- resolve unit only after all are loaded
  for _, unit_name in pairs(cands) do
    local unit = r:load_unit(unit_name)
    if unit then
      r:resolve_unit(unit)
    end
  end

  -- handle default dependencies for targets, be careful to add both directions
  -- target units automatically gain after for all of their wants/requires dependencies
  for name, unit in pairs(self.resolver.units) do
    if string.match(name, '^target%.', 1) then
      for _, tbl in pairs({unit.wants, unit.requires, unit.requisite}) do
        for _, v in pairs(tbl) do
          table.insert(unit.after, v)
        end
      end
      utils.bidi_edge(unit, 'after', 'before', function(m) return r:load_unit(m) end)
    end
  end

  -- register activation triggers for units that have them
  for name, unit in pairs(self.resolver.units) do
    if next(unit.activation.cmd) then
      table.insert(self.triggers, trigger.add_cmds(unit.activation.cmd, name, self))
    end
  end

  return self
end

return nvimctl
