-- Per-workspace server settings from `.vscode/settings.json`, so a project
-- configured for VSCode works here without a second config file.
--
-- Rewritten in Phase 3. The old implementation had two halves: an initial load
-- on lspconfig's `on_new_config`, and a live-reload file watcher on attach.
-- The `on_new_config` half fired **zero** times once servers started coming up
-- through native `vim.lsp.enable()` (it was installed by monkey-patching
-- lspconfig internals), so settings only ever applied if the file changed
-- *after* the server was already running.
--
-- Rather than restore the initial load on `before_init` - which would mean a
-- line copied into every `after/lsp/<name>.lua`, silently forgotten on the
-- next server added - both halves now run through the same code path on
-- `LspAttach`: read the file, merge over the server's static settings, push
-- `workspace/didChangeConfiguration`. That is exactly what the working half
-- already did, it needs no per-server registration, and it covers clients
-- started outside `vim.lsp.enable()` (rustaceanvim's) for free.
--
-- The cost is one extra round trip: a server starts with its static settings
-- and is corrected immediately afterwards. That is the same contract the
-- live-reload half has always relied on.

local F = vim.fn

local utils = require('ucw.utils')

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
  local fp = io.open(path, 'r')
  if not fp then
    return
  end
  local settings_str = fp:read('*a')
  fp:close()
  if not settings_str or settings_str == '' then
    return
  end
  local ok, obj = pcall(vim.json.decode, settings_str)
  if not ok or type(obj) ~= 'table' then
    return
  end
  return normalize_keys(obj)
end

---Per-client state: the settings the server was configured with (so reloads
---merge over a fixed base instead of compounding), the files being watched,
---and the watcher handles keeping themselves alive.
---@type table<integer, { base: table, files: string[], watchers: table[] }>
local state = {}

---@param client vim.lsp.Client
---@param quiet boolean whether to skip the notification (initial load)
local function reload(client, quiet)
  local st = state[client.id]
  if not st then
    return
  end

  local merged = vim.deepcopy(st.base)
  local applied = {}
  for _, file in ipairs(st.files) do
    local obj = M.load(file)
    if obj then
      merged = vim.tbl_deep_extend('force', merged, obj)
      table.insert(applied, file)
    end
  end
  if #applied == 0 then
    return
  end

  client.settings = merged
  client:notify('workspace/didChangeConfiguration', { settings = merged })

  if not quiet then
    vim.notify(
      string.format('Reloaded config:\n%s', table.concat(applied, '\n')),
      vim.log.levels.INFO,
      { title = string.format('LSP [%s]', client.name) }
    )
  end
end

---Called once per client from the LspAttach handler.
---@param client vim.lsp.Client
function M.attach(client)
  if state[client.id] then
    return
  end
  -- single-file mode has no workspace to read a .vscode/ directory from
  local folders = client.workspace_folders
  if not folders or #folders == 0 then
    return
  end

  local st = { base = vim.deepcopy(client.settings or {}), files = {}, watchers = {} }
  state[client.id] = st

  for _, folder in ipairs(folders) do
    table.insert(st.files, locate_settings_file(vim.uri_to_fname(folder.uri)))
  end

  -- the load that never used to happen
  reload(client, true)

  for _, file in ipairs(st.files) do
    local watcher = utils.FileWatcher.new(2000)
    table.insert(st.watchers, watcher)
    watcher:start(file, function()
      if client:is_stopped() then
        watcher:close()
        state[client.id] = nil
        return
      end
      reload(client, false)
    end)
  end
end

return M
