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
  local unit = self.resolver.load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  unit.disabled = false
end

---@param unit_name string
function nvimctl:disable(unit_name)
  local unit = self.resolver.load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  unit.disabled = true
end

---@param unit_name string
---@return boolean
function nvimctl:is_disabled(unit_name)
  local unit = self.resolver.load_unit(unit_name)
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


---@class nvimd.UnitNode
---@field pending number
---@field strong number
---@field weak number

---Get a graph node
---@param graph table<string, nvimd.UnitNode>
---@param name string
---@return nvimd.UnitNode
local function get_node(graph, name)
  if graph[name] == nil then
    graph[name] = {
      pending = 0,
      strong = 0,
      weak = 0,
    }
  end
  return graph[name]
end

---Check if a vunit is started and if not add it to current graph, maintaining rc counts.
---@param graph table<string, nvimd.UnitNode>
---@param stack string[]
---@param curr string
---@param vunit nvimd.Unit
---@param rc_prop string
---@param cause string
local function expand_node(graph, stack, curr, vunit, rc_prop, cause)
  if vunit and not vunit.started then
    local vnode = get_node(graph, vunit.name)
    vnode[rc_prop] = vnode[rc_prop] + 1
    if rc_prop == 'strong' and vnode[rc_prop] == 1 then
      -- first time see this node, add to stack to explore it
      table.insert(stack, vunit.name)
    end
    require('nvimd.utils.log').fmt_trace('dep %30s -- %8s --> %-30s (strong: %d, weak: %d)', curr, rc_prop, vunit.name, vnode.strong, vnode.weak)
  end
end

---start a unit as well as any dependencies
---@param unit_name string
function nvimctl:start(unit_name)
  ---@type table<string, nvimd.UnitNode>
  self.graph = {}
  local graph = self.graph
  local unit = self.resolver:load_unit(unit_name)
  assert(unit ~= nil, "Nonexisting unit " .. unit_name)
  if unit.started then
    return
  end

  -- prepare a transaction including all units
  -- use DFS to recursively add all wants and requires as strong hold, requisite as weak hold
  get_node(graph, unit_name).strong = 1 -- extra 1 strong on the starting unit
  local stack = {unit_name}
  while #stack > 0 do
    local curr = table.remove(stack)
    local cunit = self.resolver:load_unit(curr)

    if cunit and not cunit.started then
      -- insert the node
      get_node(graph, curr)
      -- handle wants/requires
      for _, v in pairs(cunit.wants) do
        local vunit = self.resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'strong', 'wants')
      end
      for _, v in pairs(cunit.requires) do
        local vunit = self.resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'strong', 'requires')
      end
      -- handle requisite
      for _, v in pairs(cunit.requisite) do
        local vunit = self.resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'weak', 'requisite')
      end
    end
  end

  require('nvimd.utils.log').trace('Generated transaction graph', { start = unit_name, graph = graph })

  if not next(graph) then
    return
  end

  -- prune the graph with disabled units and strong count == 0 units
  -- by doing a DFS following required_by
  local seen = {}
  stack = {}
  for n, v in pairs(self.resolver.units) do
    if v.disabled and graph[n] ~= nil then
      table.insert(stack, n)
    end
  end
  for n, vnode in pairs(graph) do
    if vnode.strong == 0 then
      table.insert(stack, n)
    end
  end
  while #stack > 0 do
    local curr = table.remove(stack)
    assert(curr ~= unit_name, string.format( "Failed to start %s, some of its required dependencies are disabled or not started", unit_name))

    seen[curr] = true
    local cunit = self.resolver:load_unit(curr)
    assert(cunit ~= nil, "The graph here should be trusted, check code")
    if graph[curr] then
      require('nvimd.utils.log').trace('prune ', curr)
      graph[curr] = nil
      -- update rc on upstream units
      for _, tbl in pairs({cunit.requires, cunit.wants}) do
        for _, v in pairs(tbl) do
          if graph[v] then
            graph[v].strong = graph[v].strong - 1
            if graph[v].strong == 0 then
              table.insert(stack, v)
            end
          end
        end
      end
      for _, v in pairs(cunit.requisite) do
        if graph[v] then
          graph[v].weak = graph[v].weak - 1
          assert(graph[v].weak >= 0, 'something wrong with weak?')
        end
      end
    end

    -- queue to handle units depending on curr
    for _, v in pairs(cunit.activation.required_by) do
      if not seen[v] then
        table.insert(stack, v)
      end
    end
    for _, v in pairs(cunit.activation.requisite_of) do
      if not seen[v] then
        table.insert(stack, v)
      end
    end
  end

  require('nvimd.utils.log').trace('Pruned transaction graph', { start = unit_name, graph = graph })

  if not next(graph) then
    return
  end

  require('nvimd.utils.log').trace('Adding before/after constrains', { start = unit_name })
  for name, cnode in pairs(graph) do
    local unit = self.resolver:load_unit(name)
    -- handle after only is enough, because units are resolved to have symmetric before/after
    for _, v in pairs(unit.after) do
      if graph[v] then
        cnode.pending = cnode.pending + 1
        require('nvimd.utils.log').fmt_trace('order %30s ---> %-30s (pending: %d)', v, name, cnode.pending)
      end
    end
  end

  -- topological sort and start any units without pending
  local ready = {}
  local to_activate = 0
  for n, v in pairs(graph) do
    to_activate = to_activate + 1
    if v.pending == 0 then
      table.insert(ready, n)
    end
  end
  while #ready > 0 do
    local name = table.remove(ready)
    local unit = self:activate(name)
    to_activate = to_activate - 1

    if unit then
      for _, v in pairs(unit.before) do
        if graph[v] then
          graph[v].pending = graph[v].pending - 1
          require('nvimd.utils.log').fmt_trace('order %30s ---> %-30s (pending: %d)', name, v, graph[v].pending)
          if graph[v].pending == 0 then
            table.insert(ready, v)
          end
        end
      end
    end
  end

  if to_activate > 0 then
    local cycle = {}
    for n, v in pairs(graph) do
      if v.pending > 0 then
        table.insert(cycle, n)
      end
    end
    require('nvimd.utils.log').warn('Circular ordering dependency detected among: ', to_activate, vim.inspect(cycle))
  end
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

---load packages and run their config functions from a compiled file.
---if the compiled file is not found, this simply returns false.
---in that case, just call nvimctl:sync and try boot again.
function nvimctl:boot()
  -- TODO
end

---generate packer.nvim spec and call PackerSync to install and compile file
function nvimctl:sync()
  -- TODO
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
