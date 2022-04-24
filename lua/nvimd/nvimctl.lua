---@diagnostic disable-next-line: unused-local
local L = vim.loop
---@diagnostic disable-next-line: unused-local
local F = vim.fn
---@diagnostic disable-next-line: unused-local
local A = vim.api
local au = require('au')

---@diagnostic disable-next-line: unused-local
local utils = require('nvimd.utils')
---@diagnostic disable-next-line: unused-local
local log = require('nvimd.utils.log')
local resolver = require('nvimd.resolver')
local trigger = require('nvimd.trigger')
local txn = require('nvimd.txn')


local function error_resolver_errors(unit_name, errors)
  local formatted = {}
  for _, info in pairs(errors) do
    local unit_module, err = unpack(info)
    err = string.gsub(err, '(\n\t*)', '%1\t')
    table.insert(formatted, string.format('\nFailed to load from %s.%s:\n\t%s', unit_module, unit_name, err))
  end
  error(table.concat(formatted))
end

---@class nvimd.nvimctl
---@field resolver nvimd.resolver
---@field triggers nvimd.Trigger[]
---@field paq_dir string
local nvimctl = {}

---Create a new nvimctl instance. If a name is found at multiple locations, all of them is required,
---with later overwriting fields in earlier ones.
---@param units_modules string[], list of module names containing modules
---@return nvimd.nvimctl
function nvimctl.new(units_modules)
  local self = setmetatable({}, { __index = nvimctl })

  self.resolver = resolver.new(units_modules)

  self.triggers = {}

  self.paq_dir = F.stdpath('data') .. '/site/pack/paqs/' -- the last slash is significant

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
    error_resolver_errors(unit_name, errors)
  end
end

-- actually activate the package and run its config function
---@param unit nvimd.Unit
---@return nvimd.Unit
function nvimctl._activate(unit)
  if unit.started then
    return unit
  end

  -- clear triggers since we are starting the unit
  for _, t in pairs(unit._triggers or {}) do
    t:remove()
  end
  unit._triggers = {}

  require('nvimd.utils.log').info('Activating', unit.name)

  -- unit.setup and unit.config may not be loaded yet when activating from compiled target
  if not unit.config and not unit.setup and unit._config_source and unit._config_source ~= "" then
    local ok, res = pcall(require, unit._config_source)
    if ok then
      unit.config = res.config
      unit.setup = res.setup
    else
      require('nvimd.utils.log').error('Failed to activate', unit.name, res)
      return
    end
  end

  if unit.setup then
    local ok, err_msg = pcall(unit.setup)
    if not ok then
      require('nvimd.utils.log').error('Failed to activate', unit.name, err_msg)
      return
    end
  end

  if unit._pack_name then
    local cmd = string.format('packadd %s', unit._pack_name)
    local ok, err_msg = pcall(vim.cmd, cmd)
    if not ok then
      require('nvimd.utils.log').error('Failed to activate', unit.name, err_msg)
      return
    end
  end

  -- after files are not sourced after vim enter, e.g. when manually call nvimctl:start
  -- so in that case we source them directly
  if vim.v.vim_did_enter == 1 and unit._after_files then
    for _, file in ipairs(unit._after_files) do
      vim.cmd('silent source ' .. file)
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
  unit.started = true
  require('nvimd.utils.log').info('Activated', unit.name)
  return unit
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
    return nvimctl._activate(self.resolver:load_unit(name))
  end, function(u) return not u.started end)
end

---Return nvimctl state that can be applied later
---@param units? string[] only return state of selected units
---@return table
function nvimctl:state(units)
  local state = {}
  if units == nil then
    units = vim.tbl_keys(self.resolver.units)
  end
  for _, name in pairs(units) do
    local unit = self.resolver.units[name]
    if unit then
      state[name] = {
        started = unit.started,
        _after_files = unit._after_files,
      }
    end
  end
  return state
end

function nvimctl:apply_state(state, force)
  if force == nil then
    force = false
  end
  for name, v in pairs(state) do
    if self.resolver.units[name] or force then
      self.resolver.units[name] = vim.tbl_deep_extend('force', self.resolver.units[name] or {}, v)
    end
  end
end

---Get compiled path for target
local compiled_path_base = F.stdpath('data') .. '/site/lua/nvimd/compiled/'
local function compiled_path(target)
  target = string.gsub(target, '%.', '/')
  return compiled_path_base .. target .. '.lua'
end

---compile a startup file that does the package loading to reach the
---target without a -nvimctl instance. The actual instance creation is
---done later in async
---@param target string
---@param path? string
---@return string
function nvimctl:compile(target, path)
  assert(self.resolver:load_unit(target) ~= nil, "Nonexisting unit " .. target)
  if not path then
    path = compiled_path(target)
  end

  local should_profile = true

  local compiler = require('nvimd.nvimctl.compile')

  local started_units = {}
  local compiled = compiler.prepare(should_profile)

  table.insert(compiled, [[return function()]])
  table.insert(compiled, [[  local activate = require('nvimd.nvimctl')._activate]])

  txn.do_transaction(target, self.resolver, function(name)
    local unit = self.resolver:load_unit(name)

    table.insert(started_units, unit.name)

    if should_profile then
      table.insert(compiled,string.format('time("Activate %s", true)', name))
    end
    table.insert(compiled, [[  activate({]])
    table.insert(compiled, string.format([[    name = %s,]], vim.inspect(unit.name)))
    if unit._pack_name then
      table.insert(compiled, string.format([[    _pack_name = %s,]], vim.inspect(unit._pack_name)))
    end
    if unit._config_source then
      table.insert(compiled, string.format([[    _config_source = %s,]], vim.inspect(unit._config_source)))
    end
    if unit._after_files then
      table.insert(compiled, string.format([[    _after_files = %s,]], vim.inspect(unit._after_files)))
    end
    table.insert(compiled, [[  })]])
    if should_profile then
      table.insert(compiled,string.format('time("Activate %s", false)', name))
    end
    return unit
  end)

  -- save current state for started units
  local saved_state = self:state(started_units)
  -- overide started in saved state in case the unit wasn't started now
  for _, s in pairs(saved_state) do
    s.started = true
  end

  -- do a full reload after initialization
  table.insert(compiled, string.format([[
  require('au').VimEnter = {
    '*',
    once = true,
    function()
      vim.schedule(function()
        time("Reload nvimctl", true)
        _G.nvimctl = require('nvimd.nvimctl').new(%s)
        _G.nvimctl:apply_state(%s, true)
        _G.nvimctl:reload()
        time("Reload nvimctl", false)
        save_profiles()
      end)
    end
  }
  ]],
    vim.inspect(self.resolver.units_modules),
    vim.inspect(saved_state)
  ))

  table.insert(compiled, [[end]])

  path = vim.fn.expand(path)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  local file = io.open(path, 'w')
  file:write(table.concat(compiled, '\n'))
  file:close()

  return path
end

---generate paq.vim spec and call PackerSync to install and compile file
---@param cb? fun() called when sync is done
function nvimctl:sync(cb)
  local paq = require('nvimd.boot').paq()
  paq:setup({
    path = self.paq_dir
  })
  local pkgs = {
    {'savq/paq-nvim'},
  }
  self:reload()
  for _, unit in pairs(self.resolver.units) do
    if not unit.disabled then
      if unit.url and unit.url ~= "" then
        if string.find(unit.url, [[://]]) then
          table.insert(pkgs, {
            as = unit.name,
            url = unit.url,
            run = unit.run,
            opt = true,
          })
        else
          table.insert(pkgs, {
            unit.url,
            as = unit.name,
            run = unit.run,
            opt = true,
          })
        end
      end
    end
  end
  paq(pkgs)

  if cb == nil then
    cb = function()
      -- default to compile for each target
      for _, unit in pairs(self.resolver.units) do
        if string.match(unit.name, '^target%.', 1) then
          self:compile(unit.name)
          vim.notify(unit.name, vim.log.levels.INFO, { title = '[nvimd] Finished compilation' })
        end
      end
    end
  end

  au.User = {
    'PaqDoneSync',
    function()
      self:reload(true)
      if type(cb) == 'function' then cb() end
    end,
    once = true
  }
  paq:sync()
end

---reload all units
---@param after_sync? boolean
function nvimctl:reload(after_sync)
  if after_sync == nil then
    after_sync = false
  end
  -- first preserve started info
  local state = self:state()
  -- reset everything
  for _, t in pairs(self.triggers) do
    t:remove()
  end
  self.triggers = {}
  local r = self.resolver
  r:reset()

  -- load from files
  local cands = r:discover_units()
  for _, unit_name in pairs(cands) do
    local ok, errors = r:load_unit(unit_name)
    if not ok then
      error_resolver_errors(unit_name, errors)
    end
  end
  -- resolve unit only after all are loaded
  for _, unit_name in pairs(cands) do
    local unit = r:load_unit(unit_name)
    if unit then
      r:resolve_unit(unit)
    end
  end

  -- handle default dependencies for targets, be careful to add both directions
  for name, unit in pairs(self.resolver.units) do
    if not unit.no_default_dependencies then
      -- target units automatically gain after for all of their wants/requires dependencies
      if string.match(name, '^target%.', 1) then
        for _, tbl in pairs({unit.wants, unit.requires, unit.requisite}) do
          for _, v in pairs(tbl) do
            utils.tbl_insert_uniq(unit.after, v)
          end
        end
      end
      -- everything gains an after=target.base, unless no_default_dependencies = true,
      -- which should be set on units aiming for target.base
      if name ~= 'target.base' then
        utils.tbl_insert_uniq(unit.after, 'target.base')
      end
      utils.bidi_edge(unit, 'after', 'before', function(m) return r:load_unit(m) end)
    end
  end

  -- reapply states
  self:apply_state(state)

  -- register activation triggers for units that have them
  for name, unit in pairs(self.resolver.units) do
    if not unit.started and next(unit.activation.cmd) then
      local t = trigger.add_cmds(unit.activation.cmd, name, self)
      table.insert(self.triggers, t)
      table.insert(unit._triggers, t)
    end
  end

  -- detect after files
  for name, unit in pairs(self.resolver.units) do
    local unit_path = self.paq_dir .. 'opt/' .. name
    unit._after_files = utils.detect_after_files(name, unit_path)
  end

  return self
end

---Export the graph in dot format
---@param path string output filename
---@param opts nvimd.nvimctl.GraphOpts
---@class nvimd.nvimctl.GraphOpts
---@field kind "order"|"deps" what kind of graph to export
function nvimctl:graph(path, opts)
  local g = {}
  table.insert(g, "strict digraph G {")

  for name, unit in pairs(self.resolver.units) do
    if opts.kind == 'order' then
      for _, vname in pairs(unit.after) do
        table.insert(g, string.format([["%s" -> "%s";]], vname, name))
      end
    end
    if opts.kind == 'deps' then
      for _, vname in pairs(unit.requires) do
        table.insert(g, string.format([["%s" -> "%s" [style=bold];]], name, vname))
      end
      for _, vname in pairs(unit.requisite) do
        table.insert(g, string.format([["%s" -> "%s" [style=solid];]], name, vname))
      end
      for _, vname in pairs(unit.wants) do
        table.insert(g, string.format([["%s" -> "%s" [style=dashed];]], name, vname))
      end
    end
    if string.find(name, '^target%.') then
      table.insert(g, string.format([["%s" [color = red];]], name))
    end
  end

  table.insert(g, "}")

  local fp = assert(io.open(A.fnnamemodify(path, ':p'), "w"))
  fp:write(table.concat(g, "\n"))
  fp:close()

  print(string.format('You can view the graph at http://magjac.com/graphviz-visual-editor/'))
end

return nvimctl
