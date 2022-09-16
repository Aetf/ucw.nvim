local F = vim.fn
local L = vim.loop

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

local function locate_settings_file(root_dir)
  return F.fnamemodify(root_dir, ':p') .. '.vscode/settings.json'
end

---Load .vscode/settings.json and normalize nested keys
---@param path string
---@return table|nil
function M.load(path)
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

---Apply settings and remember previous one
local function apply_settings(config, obj)
  local static_settings = config.static_settings or config.settings or {}
  static_settings = vim.deepcopy(static_settings)
  config.settings = vim.tbl_deep_extend('force', static_settings, obj)
end

---Used to inject config from root_dir
local function on_new_config_workdir(new_config, root_dir)
  new_config.static_settings = vim.deepcopy(new_config.settings)
  local path = locate_settings_file(root_dir)
  local obj = M.load(path)
  if obj then
    apply_settings(new_config, obj)
  end
end

local function dir_changed(client, settings_file)
  local obj = M.load(settings_file)
  if obj then
    apply_settings(client.config, obj)
    client.workspace_did_change_configuration(client.config.settings)
    vim.notify(
      string.format('Reloaded config:\n%s', settings_file),
      vim.log.levels.INFO,
      { title = string.format('LSP [%s]', client.name)}
    )
  end
end

local function watch_settings_change(client, _)
  -- skip for singlefile mode
  if not client.config.workspace_folders then
    return
  end
  -- for all workspace folders
  for _, folder in pairs(client.config.workspace_folders) do
    local root_dir = vim.uri_to_fname(folder.uri)
    -- watch the parent folder of the settings file
    local settings_file = locate_settings_file(root_dir)

    -- setup a luv fs event watcher on it, and a debounce time
    local watcher = utils.FileWatcher.new(2000)
    watcher:start(settings_file, function(_, _, _)
      if client:is_stopped() then
        -- we save a ref in callback so watcher won't be deleted even
        -- when the local watcher goes out of scope
        watcher:close()
        return
      end
      dir_changed(client, settings_file)
    end)
  end
end

function M.install()
  local ucwlsp = require('ucw.lsp')
  ucwlsp.register_on_new_config('.*', on_new_config_workdir)
  ucwlsp.register_on_attach('.*', watch_settings_change)
end

return M
