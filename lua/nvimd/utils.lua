local L = vim.loop

local M = {}

-- reexport submodule
M.log = require('nvimd.utils.log')

M.none = vim.NIL

function M.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
        end
        setmetatable(copy, M.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---Merge two tables recursively
---
---@generic T
---@param v1 T
---@param v2 T
---@return T
function M.merge(v1, v2)
  return vim.tbl_deep_extend('force', v1, v2)
end

function M.is_dir(path)
  local stats = L.fs_stat(path)
  return stats and stats.type == 'directory'
end

---Get the property `prop` specified as dot separated path from `obj`, creating empty table for
---all levels if not exists
function M.prop_get_table(obj, prop)
  for key in prop:gmatch "[^.]+" do
    if obj[key] == nil then
      obj[key] = {}
    end
    obj = obj[key]
  end
  return obj
end

---Get the property `prop` specified as dot separated path from `obj`,
---creating empty table if not exists for all levels except the last
---level, which is set to val
function M.prop_set(obj, prop, val)
  -- get the parent level as table
  local parent, key = string.match(prop, "(.+)%.([^%.]+)")
  M.prop_get_table(obj, parent)[key] = val
end

---for target unit in unit[prop_from], set corresponding target_unit[prop_to] = unit.name
function M.bidi_edge(unit, prop_from, prop_to, load)
  for _, want in pairs(M.prop_get_table(unit, prop_from)) do
    local target_unit = load(want)
    if target_unit then
      if not vim.tbl_contains(M.prop_get_table(target_unit, prop_to), unit.name) then
        table.insert(M.prop_get_table(target_unit, prop_to), unit.name)
      end
    else
      require('nvimd.utils.log').fmt_warn('%s references non-existing unit: %s', unit.name, want)
    end
  end
end

local after_files_pattern = [[after/plugin/**/*.\(vim\|lua\)]]
---Glob after files for plugin
---@param name string
---@param unit_path string
function M.detect_after_files(name, unit_path)
  local path = unit_path .. '/' .. after_files_pattern
  local glob_ok, files = pcall(vim.fn.glob, path, false, true)
  if not glob_ok then
    if string.find(files, 'E77') then
      return { path }
    else
      error('Error compiling ' .. name .. ': ' .. vim.inspect(files))
    end
  elseif #files > 0 then
    return files
  end

  return nil
end

---Reload module `prefix` and `prefix.`
---@param prefix string
function M.reload(prefix)
  local function match(mod)
    return mod == prefix or string.find(mod, '^' .. vim.pesc(prefix) .. '%.')
  end
  -- Clear lua module cache
  -- also Handle impatient.nvim automatically.
  ---@diagnostic disable-next-line: undefined-field
  local luacache = (_G.__luacache or {}).cache
  for module, _ in pairs(package.loaded) do
    if match(module) then
      package.loaded[module] = nil
      if luacache then
        luacache[module] = nil
      end
    end
  end
end

return M
