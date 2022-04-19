local F = vim.fn
local utils = require('ucw.utils')
local logger = require('ucw.log').logger()

local M = {}

---Normalize object keys
---i.e. from {["a.b.c"] = 1} to {a = { b = { c = 1 }}}
local function normalize_keys(obj)
  if type(obj) ~= 'table' then
    return obj
  end

  local res = {}
  for k, v in pairs(obj) do
    utils.prop_set(res, k, normalize_keys(v))
  end
  return res
end

---Load .vscode/settings.json and normalize nested keys
---@param path string
---@return table|nil
function M.load(path)
  path = F.fnamemodify(path, ':p') .. '.vscode/settings.json'
  -- open file
  local fp, _ = io.open(path, 'r')
  if not fp then
    return
  end
  -- load string
  local settings_str = fp:read('*a')
  if not settings_str then
    return
  end
  -- decode json
  local obj = vim.fn.json_decode(settings_str)
  if not obj then
    return
  end
  -- normalize keys
  local settings = normalize_keys(obj)
  return settings
end

---Used to inject config from root_dir
local function on_new_config_workdir(new_config, root_dir)
  local obj = M.load(root_dir)
  if obj then
    -- apply to settings
    new_config.settings = vim.tbl_deep_extend('force', new_config.settings, obj)
  end
end

function M.setup()
  local ucwlsp = require('ucw.lsp')
  ucwlsp.register_on_new_config('.*', on_new_config_workdir)
end

return M
