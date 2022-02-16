---@diagnostic disable-next-line: unused-local
local L = vim.loop
---@diagnostic disable-next-line: unused-local
local F = vim.fn
---@diagnostic disable-next-line: unused-local
local A = vim.api
---@diagnostic disable-next-line: unused-local
local utils = require('nvimd.utils')
local resolver = require('nvimd.resolver')


---@class nvimd.nvimctl
---@field resolver nvimd.resolver
---@field graph table<string, nvimd.UnitNode>
local nvimctl = {}

---Create a new nvimctl instance. If a name is found at multiple locations, all of them is required,
---with later overwriting fields in earlier ones.
---@param units_modules string[], list of module names containing modules
---@return nvimd.nvimctl
function nvimctl.new(units_modules)
  local self = setmetatable({}, { __index = nvimctl })

  self.resolver = resolver.new(units_modules)

  self.graph = {}

  self:reload()

  return self
end

---@param unit_name string
function nvimctl:enable(unit_name)
  local unit = self.resolver.load_unit(unit_name)
  if not unit then
    return
  end
  unit.disabled = false
end

---@param unit_name string
function nvimctl:disable(unit_name)
  local unit = self.resolver.load_unit(unit_name)
  if not unit then
    return
  end
  unit.disabled = true
end

---@param unit_name string
---@return boolean
function nvimctl:is_disabled(unit_name)
  local unit = self.resolver.load_unit(unit_name)
  if not unit then
    return nil
  end
  return unit.disabled
end

---@param unit_name string
function nvimctl:status(unit_name)
  local unit = self.resolver:load_unit(unit_name)
  if not unit then
    return
  end
  print(vim.inspect(unit))
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
  graph[name] = graph[name] or {
    pending = 0,
    strong = 0,
    weak = 0,
  }
  return graph[name]
end

---mark a unit as the start target
---@param unit_name string
function nvimctl:start(unit_name)
  ---@type table<string, nvimd.UnitNode>
  self.graph = {}
  local graph = self.graph
  get_node(graph, unit_name).strong = 1
  assert(self.resolver:load_unit(unit_name) ~= nil, "Nonexisting unit " .. unit_name)
  -- prepare a transaction including all units
  -- use DFS to recursively add all wants and requires
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
        if vunit and not vunit.started then
          local vnode = get_node(graph, v)
          vnode.weak = vnode.weak + 1
          if vnode.weak + vnode.strong == 1 then
            table.insert(stack, v)
          end
        else
          print('Skiping wanting already started ' .. v)
        end
      end
      for _, v in pairs(cunit.requires) do
        local vunit = self.resolver:load_unit(v)
        if vunit and not vunit.started then
          local vnode = get_node(graph, v)
          vnode.strong = vnode.strong + 1
          if vnode.strong + vnode.weak == 1 then
            table.insert(stack, v)
          end
        else
          print('Skiping requiring already started ' .. v)
        end
      end
    end
  end

  print('Adding before/after constrains')
  for name, cnode in pairs(graph) do
    local unit = self.resolver:load_unit(name)
    -- handle after
    for _, v in pairs(unit.after) do
      if graph[v] then
        cnode.pending = cnode.pending + 1
      end
    end
  end

  print('Generated transaction graph')
  print(vim.inspect(graph))

  -- prune the graph with disabled units
  -- by doing a DFS following required_by
  local seen = {}
  stack = {}
  for n, v in pairs(self.resolver.units) do
    if v.disabled then
      table.insert(stack, n)
    end
  end
  while #stack > 0 do
    local curr = table.remove(stack)
    assert(curr ~= unit_name, string.format( "Failed to start %s, some of its required dependencies are disabled", unit_name))

    seen[curr] = true
    local cunit = self.resolver:load_unit(curr)
    assert(cunit ~= nil, "The graph here is trusted, check code")
    if graph[curr] then
      graph[curr] = nil
      -- update rc on upstream units
      for _, v in pairs(cunit.requires) do
        if graph[v] then
          graph[v].strong = graph[v].strong - 1
          if graph[v].strong == 0 and graph[v].weak == 0 then
            table.insert(stack, v)
          end
        end
      end
      for _, v in pairs(cunit.wants) do
        if graph[v] then
          graph[v].weak = graph[v].weak - 1
          if graph[v].strong == 0 and graph[v].weak == 0 then
            table.insert(stack, v)
          end
        end
      end
      -- remove curr from others pending array
      for _, v in pairs(cunit.before) do
        if graph[v] then
          graph[v].pending = graph[v].pending - 1
          assert(graph[v].pending >= 0, 'something wrong with pending?')
        end
      end
    end

    -- queue to handle units depending on curr
    for _, v in pairs(cunit.activation.required_by) do
      if not seen[v] then
        table.insert(stack, v)
      end
    end
  end

  print('Pruned transaction graph')
  print(vim.inspect(graph))

  -- topological sort and start any units without pending
  local ready = {}
  for n, v in pairs(graph) do
    if v.pending == 0 then
      table.insert(ready, n)
    end
  end
  while #ready > 0 do
    local name = table.remove(ready)
    local unit = self:activate(name)

    if unit then
      for _, v in pairs(unit.before) do
        if graph[v] then
          graph[v].pending = graph[v].pending - 1
          if graph[v].pending == 0 then
            table.insert(ready, v)
          end
        end
      end
    end
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
    print(string.format('[nvimd] Activating %s: packadd %s', unit.name, unit.pack_name))
    local cmd = string.format('packadd %s', unit.pack_name)
    local ok, _ = pcall(vim.cmd, cmd)
    if not ok then
      print('[nvimd] Failed to activate ', unit.name)
      return
    end
  end
  if unit.config then
    local ok, _ pcall(unit.config)
    if not ok then
      print('[nvimd] Failed to activate ', unit.name)
      return
    end
    print(string.format('[nvimd] Configuring %s', unit.name))
  end
  print(string.format('[nvimd] Activated %s', unit.name))

  return unit
end

---actually load packages and run their config functions from a compiled file.
---if the compiled file is not found, this simply returns false.
---in that case, just call nvimctl:sync and try boot again.
function nvimctl:boot()
end

---generate packer.nvim spec and call PackerSync to install and compile file
function nvimctl:sync()
end

---reload all units
function nvimctl:reload()
  self.graph = {}
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

  -- handle default dependencies for targets
  for name, unit in pairs(self.resolver.units) do
    if string.match(name, '^target%.', 1) then
      for _, v in pairs(unit.wants) do
        table.insert(unit.after, v)
      end
      for _, v in pairs(unit.requires) do
        table.insert(unit.after, v)
      end
    end
  end

  return self
end

return nvimctl
