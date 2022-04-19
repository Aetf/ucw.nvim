--[[
-- This module implements centralized hook handling for lsp:
-- * on_server_ready
-- * on_new_config
-- * on_attach
--
-- Each hook can come from different sources:
-- * ucw.lsp.lang.*.<hook_name>
-- * plugin registered
--
-- The general process of hooks are:
-- * nvim-lsp-installer takes care of installing the server
-- * various plugins register integration functions using one of
--   `ucw.lsp.hooks.register_on_server_ready`
--   `ucw.lsp.hooks.register_on_new_config`
--   `ucw.lsp.hooks.register_on_attach`
--
-- During on_server_ready,
-- * lsp-installer server:default_options is used as base
-- * hooks from ucw.lsp.lang.* are called
-- * hooks plugins are called
-- * either the default server setup which calls server:setup directly
--   or plugin can supply custom server setup function
--
-- During on_new_config
-- * additional options from workspace (`.vscode/settings.json`) are used as base
-- * hooks from ucw.lsp.lang.* are called
-- * hooks plugins are called
--
-- During on_attach
-- * hooks from ucw.lsp.lang.* are called
-- * hooks plugins are called
--]]
local M = {}

---@class ucw.lsp.hooks.Hook
---@field ptn string
---@field cb fun()

---@type table<string, ucw.lsp.hooks.Hook[]>
local hooks = {
  on_server_ready = {},
  on_new_config = {},
  on_attach = {},
}

local function call_hook(hook_name, server_name, ...)
  -- call from lang module
  local present, m = pcall(require, 'ucw.lsp.lang.' .. server_name)
  if present and m[hook_name] ~= nil then
    local ok, err = pcall(m[hook_name], ...)
    if not ok then
      vim.notify(
        string.format("Failed to call `ucw.lsp.lang.%s.%s': %s", server_name, hook_name, err),
        vim.log.levels.ERROR,
        { title = "[ucw.lsp] on_server_ready error" }
      )
    end
  end

  -- call registered hooks
  for _, hook in ipairs(hooks[hook_name]) do
    if string.find(server_name, hook.ptn) then
      hook.cb(...)
    end
  end
end

local custom_server_setups = {}
---register a custom setup function for name. This can only be called once for each name
---@param name string exactly the server name
---@param custom_setup fun(server, opts)
function M.register_server_setup(name, custom_setup)
  if custom_server_setups[name] then
    vim.notify(
      string.format(
        "Multiple calls to register_server_setup on %s, previous config is %s",
        name,
        vim.inspect(custom_server_setups[name])
      ),
      vim.log.levels.WARN,
      { title = "[ucw.lsp] register_server_setup" }
    )
  end
  custom_server_setups[name] = custom_setup
end

---register the on_server_ready hook
---@param ptn string
---@param cb fun(server, opts)
function M.register_on_server_ready(ptn, cb)
  table.insert(hooks.on_server_ready, { ptn=ptn, cb=cb })
end

---register the on_new_config hook
---@param ptn string
---@param cb fun(server, opts)
function M.register_on_new_config(ptn, cb)
  table.insert(hooks.on_new_config, { ptn=ptn, cb=cb })
end

---register the on_attach hook
---@param ptn string
---@param cb fun(server, opts)
function M.register_on_attach(ptn, cb)
  table.insert(hooks.on_attach, { ptn=ptn, cb=cb })
end

local function server_setup(server, opts)
  if custom_server_setups[server.name] ~= nil then
    custom_server_setups[server.name](server, opts)
  else
    server:setup(opts)
  end
end

-- During on_server_ready,
-- * lsp-installer server:default_options is used as base
-- * hooks from ucw.lsp.lang.* are called
-- * hooks plugins are called
-- * either the default server setup which calls server:setup directly
--   or plugin can supply custom server setup function
function M.do_on_server_ready(server)
  -- lsp-installer default options as base
  local opts = server:get_default_options()

  -- call hooks
  call_hook('on_server_ready', server.name, server, opts)

  local lspconfig = require('lspconfig')
  -- make sure lspconfig hooks are always called
  if opts.on_new_config ~= nil then
    opts.on_new_config = lspconfig.util.add_hook_after(lspconfig.util.default_config.on_new_config, opts.on_new_config)
  end
  if opts.on_attach ~= nil then
    opts.on_attach = lspconfig.util.add_hook_after(lspconfig.util.default_config.on_attach, opts.on_attach)
  end

  -- mix in our hooks
  opts.on_new_config = lspconfig.util.add_hook_after(opts.on_new_config, M.do_on_new_config)
  opts.on_attach = lspconfig.util.add_hook_after(opts.on_attach, M.do_on_attach)

  -- actual lsp-installer setup
  server_setup(server, opts)
end

function M.do_on_new_config(new_config, root_dir)
  call_hook('on_new_config', new_config.name, new_config, root_dir)
end

function M.do_on_attach(client, bufnr)
  call_hook('on_attach', client.name, client, bufnr)
end

return M
