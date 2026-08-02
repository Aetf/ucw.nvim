-- Per-workspace server settings from the project's `.vscode/` directory, so a
-- project configured for VSCode works here without a second config file.
--
-- **This module is the only writer of `client.settings`.** That is the whole
-- design; see docs/design/phase3-settings-composition.md.
--
-- It used to share the slot with `ucw.lsp.ltex_dict`, which loaded the ltex
-- dictionary files out of the same `.vscode/` directory and wrote the result
-- into `client.settings` after this module had already assigned it. Since a
-- reload here recomputes from a snapshot taken at attach, every edit to
-- `settings.json` in a vault silently un-learned every word ever added to it
-- (Phase 3 acceptance review, P2). The first fix announced each reload so the
-- other writer could re-apply; this replaces that with the observation that
-- there was never a second source to compose with:
--
--   `.vscode/ltex.dictionary.en-US.txt` *is* a `.vscode` setting. It is the
--   file-backed spelling of `settings.ltex.dictionary['en-US']`, defined by the
--   same VSCode LTeX convention that names `settings.json` - the extension
--   reads `WORKSPACE_FOLDER/.vscode/ltex.SETTING.LANGUAGE.txt` implicitly, with
--   no reference from `settings.json` needed.
--
-- So the directory has one reader, `client.settings` has one writer, and the
-- module that owns the ltex commands is back to only writing files.
--
-- Both halves - initial load and live reload - run through `M.reload` on
-- `LspAttach` and on every watcher hit. The cost is one extra round trip after
-- the server starts, which is the contract the live-reload half always had.

local F = vim.fn

local utils = require('ucw.utils')

local M = {}

--- Settings keys that may additionally be written as sibling text files, one
--- file per variant: `<dir>/ltex.dictionary.en-US.txt` contributes its non-empty
--- lines to `settings.ltex.dictionary['en-US']`, *unioned* with whatever
--- `settings.json` declared for the same key.
---
--- Not an invention: this is the implicit-default-path half of VSCode LTeX's own
--- convention (docs/design/phase3-settings-composition.md §2b), which is why a
--- `.vscode/` written here is readable by VSCode and vice versa. The mechanism
--- is key-agnostic; this list is data.
---
--- Not implemented, deliberately: the other half of that convention, where a
--- list entry beginning with `:` names an external file explicitly (resolved
--- relative to the `.vscode` directory, `~` expanded). This config has never had
--- it; it is a feature, not part of this refactor.
---@type string[]
local SIDECAR_KEYS = {
  'ltex.dictionary',
  'ltex.hiddenFalsePositives',
  'ltex.disabledRules',
}

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

---The user-scope settings directory, read for every client.
---
---The name is historical: this is where the existing global ltex dictionaries
---live, and a tidier name would orphan them. It is the analogue of VSCode's
---`LTEX_GLOBAL_STORAGE_PATH`, which is also read implicitly.
---@return string
function M.global_dir()
  return F.stdpath('data') .. '/ltex'
end

---The settings directory of a workspace root.
---@param root string
---@return string
function M.workspace_dir(root)
  return F.fnamemodify(root, ':p') .. '.vscode'
end

---Every settings directory that applies to a client, lowest priority first:
---user scope, then one per workspace folder. A single-file client still gets
---the user-scope one - which is exactly where words added without a project go.
---
---Does **not** create anything. Creating a directory while looking for a file in
---it is what used to leave an empty `.vscode/` behind in every project that ever
---opened a prose file (docs/design/phase3-settings-composition.md §1).
---@param client vim.lsp.Client
---@return string[]
function M.settings_dirs(client)
  local dirs = { M.global_dir() }
  for _, folder in ipairs(client.workspace_folders or {}) do
    table.insert(dirs, M.workspace_dir(vim.uri_to_fname(folder.uri)))
  end
  return dirs
end

---Where the sidecar file for `key`/`variant` lives inside `dir`.
---@param dir string
---@param key string dotted settings key, e.g. 'ltex.dictionary'
---@param variant string e.g. 'en-US'
---@return string
function M.sidecar_path(dir, key, variant)
  return string.format('%s/%s.%s.txt', dir, key, variant)
end

---Merge every sidecar file found in `dir` into `acc`.
---
---Union, not replacement: a `settings.json` that declares
---`ltex.dictionary['en-US']` keeps its entries and the file's are appended.
---`vim.tbl_deep_extend` cannot express that - measured, it replaces a nested
---list wholesale (design §2) - which is why sidecars are merged here instead of
---being turned into a table and handed to it.
---@param acc table
---@param dir string
local function read_sidecars(acc, dir)
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= 'directory' then
    return
  end

  for name, kind in vim.fs.dir(dir) do
    if kind == 'file' then
      for _, key in ipairs(SIDECAR_KEYS) do
        local variant = name:match('^' .. vim.pesc(key) .. '%.(.+)%.txt$')
        if variant then
          local by_variant = utils.prop_get_table(acc, key)
          if type(by_variant[variant]) ~= 'table' then
            by_variant[variant] = {}
          end
          for _, line in ipairs(F.readfile(dir .. '/' .. name)) do
            if line ~= '' then
              utils.tbl_insert_uniq(by_variant[variant], line)
            end
          end
        end
      end
    end
  end
end

---Per-client state: the settings the server was configured with (so reloads
---compose over a fixed base instead of compounding) and the watcher handles
---keeping themselves alive.
---@type table<integer, { base: table, watchers: table[] }>
local state = {}

---Recompute a client's settings from its `.vscode/` directories and push them.
---
---Idempotent, and silent when nothing changed - which is what keeps a server
---from being woken four times to open one file (design §1).
---@param client vim.lsp.Client
---@return boolean changed
function M.reload(client)
  local st = state[client.id]
  if not st then
    return false
  end

  -- The base is the attach-time snapshot rather than
  -- `vim.lsp.config[client.name].settings`: the native lookup is measured
  -- identical for the servers we enable, but it is `nil` for `rust-analyzer`,
  -- since rustaceanvim starts that client itself - and covering that client for
  -- free is why this lives on `LspAttach` at all.
  local acc = vim.deepcopy(st.base)
  for _, dir in ipairs(M.settings_dirs(client)) do
    local obj = M.load(dir .. '/settings.json')
    if obj then
      acc = vim.tbl_deep_extend('force', acc, obj)
    end
    read_sidecars(acc, dir)
  end

  if vim.deep_equal(acc, client.settings) then
    return false
  end

  client.settings = acc
  client:notify('workspace/didChangeConfiguration', { settings = acc })
  return true
end

---Called once per client from the LspAttach handler.
---@param client vim.lsp.Client
function M.attach(client)
  if state[client.id] then
    return
  end
  local st = { base = vim.deepcopy(client.settings or {}), watchers = {} }
  state[client.id] = st

  -- the load that never used to happen
  M.reload(client)

  -- Known gap, measured and pre-existing (A/B'd against the tree before this
  -- rewrite, where it behaves identically): the watcher is started on the
  -- *file*, so `uv.fs_event_start` fails silently when `settings.json` does not
  -- exist yet. Creating one in an already-open project is therefore not picked
  -- up until the client restarts. Fixing it means watching the directory - a
  -- watcher-lifetime change, not a composition one, so it is deliberately not
  -- part of this refactor.
  for _, folder in ipairs(client.workspace_folders or {}) do
    local file = M.workspace_dir(vim.uri_to_fname(folder.uri)) .. '/settings.json'
    local watcher = utils.FileWatcher.new(2000)
    table.insert(st.watchers, watcher)
    watcher:start(file, function()
      if client:is_stopped() then
        M.detach(client.id)
        return
      end
      if M.reload(client) then
        vim.notify(
          string.format('Reloaded config:\n%s', file),
          vim.log.levels.INFO,
          { title = string.format('LSP [%s]', client.name) }
        )
      end
    end)
  end
end

---Whether a `.vscode/settings.json` watcher is currently running for a client.
---Exists so the lifetime is observable - from a test, and from `:lua =` when
---wondering why a settings file is or is not being picked up.
---@param client_id integer
---@return boolean
function M.is_watching(client_id)
  local st = state[client_id]
  return st ~= nil and #st.watchers > 0
end

---Stop watching for a client that is gone, and drop its base snapshot.
---
---The watchers used to be torn down only if one of them happened to fire again
---after the client had stopped, so a `:LspRestart` or a crash left a 2-second
---poll running for the rest of the session, with its `state` entry pinned
---(Phase 3 acceptance review, P5). `M.setup()` below hangs this off
---`LspDetach`; the in-watcher call above stays as the belt-and-braces path for
---a client that dies without detaching.
---@param client_id integer
function M.detach(client_id)
  local st = state[client_id]
  if not st then
    return
  end
  state[client_id] = nil
  for _, watcher in ipairs(st.watchers) do
    watcher:close()
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('LspDetach', {
    group = vim.api.nvim_create_augroup('ucw.lsp.vscode', { clear = true }),
    desc = 'ucw: stop watching .vscode/settings.json for a departed client',
    callback = function(args)
      local client_id = args.data.client_id
      -- LspDetach is per *buffer*, and it fires while the buffer is still in
      -- `client.attached_buffers` (client.lua:1363 runs before :1392), so
      -- "is this the last one" means "is any *other* buffer still attached".
      -- The client stays useful - and its watcher stays up - as long as one is.
      local still_attached = vim.iter(vim.lsp.get_buffers_by_client_id(client_id)):any(function(buf)
        return buf ~= args.buf
      end)
      if not still_attached then
        M.detach(client_id)
      end
    end,
  })
end

return M
