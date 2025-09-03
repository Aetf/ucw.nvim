--[[
-- This module implements centralized hook handling for lsp with the ability to
-- filter based on server name:
-- * on_server_setup
-- * on_new_config
-- * on_attach
--
-- Hooks can come from different sources:
-- * ucw.lsp.lang.*.<hook_name>
-- * plugin registered
--
-- The general process of hooks are:
-- * mason takes care of installing the server
-- * mason-lspconfig will hook into lspconfig's on_setup to update binary path
-- * ucw.lsp.hooks will hook into lspconfig's on_setup to provide customization points
-- * various plugins register integration functions using one of
--   + `ucw.lsp.hooks.register_on_server_setup`
--   + `ucw.lsp.hooks.register_on_new_config`
--   + `ucw.lsp.hooks.register_on_attach`
-- * LSP target enabled
-- * mason-lspconfig will trigger vim.lsp.enable for installed servers
-- * vim.lsp.enable([server_name]) is called
-- * lspconfig's on_setup hooks are called
--   + mason-lspconfig's on_setup
--   + ucw.lsp.hooks's on_setup
--     - call on_server_setup
--     - hook on_new_config and on-attach
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
  on_server_setup = {},
  on_new_config = {},
  on_attach = {},
}

local function call_hook(hook_name, server_name, ...)
  -- call from lang module
  local present, m = pcall(require, 'ucw.lsp.lang.' .. server_name)
  if present and m[hook_name] ~= nil then
    local ok, err_or_stop = pcall(m[hook_name], ...)
    if not ok then
      vim.notify(
        string.format("Failed to call `ucw.lsp.lang.%s.%s':\n%s", server_name, hook_name, err_or_stop),
        vim.log.levels.ERROR,
        { title = "[ucw.lsp] on_server_setup error" }
      )
    else
      if err_or_stop then
        return
      end
    end
  elseif not present then
    -- notify for errors other than module not found
    if not string.find(m, 'not found:') then
      vim.notify(
        string.format("Failed to load `ucw.lsp.lang.%s':\n%s", server_name, vim.inspect(m)),
        vim.log.levels.ERROR,
        { title = "[ucw.lsp] Hook Error" }
      )
    end
  end

  -- call registered hooks
  for _, hook in ipairs(hooks[hook_name]) do
    if string.find(server_name, hook.ptn) then
      local ok, err_or_stop = pcall(hook.cb, ...)
      if not ok then
        vim.notify(
          string.format("Failed to call %s for %s':\n%s", hook_name, server_name, err_or_stop),
          vim.log.levels.ERROR,
          { title = "[ucw.lsp] Hook Error" }
        )
      else
        if err_or_stop then
          return
        end
      end
    end
  end
end

---register the on_server_setup hook.
---This can be used to update server opts that are not dependent on root_dir.
---@param ptn string
---@param cb fun(opts)
function M.register_on_server_setup(ptn, cb)
  table.insert(hooks.on_server_setup, { ptn=ptn, cb=cb })
end

---register the on_new_config hook
---This can be used to update server opts that are dependent on root_dir.
---@param ptn string a pattern matching the lsp server name
---@param cb fun(new_config, root_dir)
function M.register_on_new_config(ptn, cb)
  table.insert(hooks.on_new_config, { ptn=ptn, cb=cb })
end

---register the on_attach hook
---@param ptn string
---@param cb fun(client, bufnr)
function M.register_on_attach(ptn, cb)
  table.insert(hooks.on_attach, { ptn=ptn, cb=cb })
end

---install all hooks to lspconfig
function M.install()
  local lspconfig = require('lspconfig')
  local lutil = require('lspconfig.util')

  -- mix in our hooks in global defaults
  lutil.default_config = vim.tbl_extend(
    'force',
    lutil.default_config,
    {
      on_new_config = lutil.add_hook_after(lutil.default_config.on_new_config, function(new_config, root_dir)
        call_hook('on_new_config', new_config.name, new_config, root_dir)
      end),
    }
  )
  -- use autocmd for on_attach
  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
      local bufnr = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      call_hook('on_attach', client.name, client, bufnr)
    end
  })

  -- add in our setup hooks
  lutil.on_setup = lutil.add_hook_after(
    lutil.on_setup,
    function(config, user_config)
      call_hook('on_server_setup', config.name, config)
    end
  )
end

function M.activate()
  -- all LSP servers are enabled as part of mason-lspconfig activation, which is
  -- part of LSP target.
end

return M
