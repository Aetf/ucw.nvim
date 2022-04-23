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
  -- for all workspace folders
  for _, folder in pairs(client.config.workspace_folders) do
    local root_dir = vim.uri_to_fname(folder.uri)
    -- watch the parent folder of the settings file
    local settings_file = locate_settings_file(root_dir)

    -- setup a luv fs event watcher on it, and a debounce time
    local state = {
      timer = L.new_timer(),
      watcher = L.new_fs_event(),
      debouncing = false,
      cb = setmetatable({ weak = nil }, { __mode = 'v' }),
    }
    state.cb.weak = function(err, _, events)
      if err ~= nil then
        vim.schedule(function()
          vim.notify(err, vim.log.lvels.ERROR, { title = '[ucw.lsp.vscode] Error in libuv watcher' })
        end)
        return
      end
      if not events.change and not events.rename then
        return
      end
      if state.debouncing or state.timer:is_active() then
        return
      end
      state.debouncing = true
      state.timer:start(2000, 0, function()
        if client:is_stopped() then
          state.watcher:stop()
          state.watcher:close()
          state.timer:stop()
          state.timer:close()
          return
        end
        vim.schedule(function()
          dir_changed(client, settings_file)
          state.debouncing = false
        end)
      end)

      -- refresh watcher so in case the file is renamed we still watch it
      -- we save a strong reference to cb first, then stop the watcher, which should remove the only other strong reference to cb
      local cb = state.cb.weak
      state.watcher:stop()
      state.watcher:start(settings_file, {}, cb)
    end
    state.watcher:start(settings_file, {}, state.cb.weak)
  end
end

function M.setup()
  local ucwlsp = require('ucw.lsp')
  ucwlsp.register_on_new_config('.*', on_new_config_workdir)
  ucwlsp.register_on_attach('.*', watch_settings_change)
end

return M
