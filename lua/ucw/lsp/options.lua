--[[
-- This module implements ucw.lsp server config handler, the static part.
-- I.e. those without workspace specific settings, as these are loaded during
-- the target activation.
--]]
local M = {}

local common_opts = {}

-- For common options applied to all servers
function M.setup_common(opts)
  common_opts = vim.tbl_deep_extend('force', common_opts, opts)
end

local enhance_server_opts = {}
-- For additional plugins' setup code to integrate.
-- The passed in `server_setup` has the following signature:
-- server_setup(server, opts)
-- And is expected to call server:setup(opts) eventually.
---@param name string name of the language server
---@param server_setup fun(server:any, opts:any)
function M.custom_server_setup(name, server_setup)
  if enhance_server_opts[name] then
    vim.notify(
      string.format(
        "Multiple calls to custom_server_setup on %s, previous config is %s",
        name,
        vim.inspect(enhance_server_opts[name])
      ),
      vim.log.levels.WARN,
      { title = "ucw.lsp" }
    )
  end
  enhance_server_opts[name] = server_setup
end

local function default_server_setup(server, opts)
  server:setup(opts)
end

-- Each server's option is sourced from
-- * common options
-- * server specific options from lang module
-- * workspace specific options if any
function M.get_server(name)
  local server_setup = enhance_server_opts[name] or default_server_setup

  -- common options
  local server_opts = vim.deepcopy(common_opts)

  -- options from lang module
  local present, apply_lang_opts = pcall(require, 'ucw.lsp.lang.' .. name)
  if present then
    apply_lang_opts(server_opts)
  end

  -- workspace options will be merged in during on_new_config handler
  return server_opts, server_setup
end

function M.on_server_ready(server)
  local server_opts, server_setup = M.get_server(server.name)
  server_setup(server, server_opts)
end

return M
