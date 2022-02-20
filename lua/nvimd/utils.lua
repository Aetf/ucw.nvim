local L = vim.loop

local M = {}

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

return M
