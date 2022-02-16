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

return M
