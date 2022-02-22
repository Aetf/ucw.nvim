local M = {}

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
---@param filter fun(nvimd.Unit):boolean
local function expand_node(graph, stack, curr, vunit, rc_prop, cause, filter)
  if vunit and filter(vunit) then
    local vnode = get_node(graph, vunit.name)
    vnode[rc_prop] = vnode[rc_prop] + 1
    if rc_prop == 'strong' and vnode[rc_prop] == 1 then
      -- first time see this node, add to stack to explore it
      table.insert(stack, vunit.name)
    end
    require('nvimd.utils.log').fmt_trace('dep %30s -- %8s --> %-30s (strong: %d, weak: %d)', curr, rc_prop, vunit.name, vnode.strong, vnode.weak)
  end
end

---Build the transaction graph and call fn on each unit in topological
---order
---@param unit_name string
---@param resolver nvimd.resolver
---@param fn fun(name:string):nvimd.Unit
---@param filter? fun(u:nvimd.Unit):boolean
function M.do_transaction(unit_name, resolver, fn, filter)
  if filter == nil then
    filter = function() return true end
  end
  ---@type table<string, nvimd.UnitNode>
  local graph = {}
  -- prepare a transaction including all units
  -- use DFS to recursively add all wants and requires as strong hold, requisite as weak hold
  get_node(graph, unit_name).strong = 1 -- extra 1 strong on the starting unit
  local stack = {unit_name}
  while #stack > 0 do
    local curr = table.remove(stack)
    local cunit = resolver:load_unit(curr)

    if cunit and filter(cunit) then
      -- insert the node
      get_node(graph, curr)
      -- handle wants/requires
      for _, v in pairs(cunit.wants) do
        local vunit = resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'strong', 'wants', filter)
      end
      for _, v in pairs(cunit.requires) do
        local vunit = resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'strong', 'requires', filter)
      end
      -- handle requisite
      for _, v in pairs(cunit.requisite) do
        local vunit = resolver:load_unit(v)
        expand_node(graph, stack, curr, vunit, 'weak', 'requisite', filter)
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
  for n, v in pairs(resolver.units) do
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
    local cunit = resolver:load_unit(curr)
    assert(cunit ~= nil, "The graph here should be trusted, check code")
    if graph[curr] then
      -- graph[curr].strong may be 0 when this is only a weak required
      -- unit, in which case it was not expanded, so no need to update
      -- rc counts for it
      if graph[curr].strong ~= 0 then
        -- update rc on upstream units
        for _, tbl in pairs({cunit.requires, cunit.wants}) do
          for _, v in pairs(tbl) do
            if graph[v] then
              graph[v].strong = graph[v].strong - 1
              if graph[v].strong == 0 then
                require('nvimd.utils.log').fmt_trace('prune no longer required %s -> %s', v, curr)
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
      graph[curr] = nil
    end

    -- queue to handle units depending on curr
    for _, v in pairs(cunit.activation.required_by) do
      if not seen[v] then
        require('nvimd.utils.log').fmt_trace('prune required %s -> %s', curr, v)
        table.insert(stack, v)
      end
    end
    for _, v in pairs(cunit.activation.requisite_of) do
      if not seen[v] then
        require('nvimd.utils.log').fmt_trace('prune requisite %s -> %s', curr, v)
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
    local unit = resolver:load_unit(name)
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
  local has_error = false
  for n, v in pairs(graph) do
    to_activate = to_activate + 1
    if v.pending == 0 then
      table.insert(ready, n)
    end
  end
  require('nvimd.utils.log').fmt_trace('Activating %s units', to_activate)
  while #ready > 0 do
    local name = table.remove(ready)
    local unit = fn(name)
    to_activate = to_activate - 1

    if unit then
      for _, v in pairs(unit.before) do
        if graph[v] then
          graph[v].pending = graph[v].pending - 1
          require('nvimd.utils.log').fmt_trace('pending - 1 %30s ---> %-30s (pending: %d)', name, v, graph[v].pending)
          if graph[v].pending == 0 then
            table.insert(ready, v)
          end
        end
      end
    else
      has_error = true
    end
  end

  if not has_error and to_activate > 0 then
    local cycle = {}
    for n, v in pairs(graph) do
      if v.pending > 0 then
        table.insert(cycle, v)
      end
    end
    require('nvimd.utils.log').warn('Circular ordering dependency detected among: ', to_activate, vim.inspect(cycle))
  end
end

return M
