-- [[
-- LSP integration framework that coordinates the setup between
-- nvim-lsp-installer, nvim-lspconfig, various enhance plugins and
-- any user custom language settings.
--
-- The general process is:
-- * nvim-lsp-installer takes care of installing the server
-- * various plugins register integration function using
--   `ucw.lsp.custom_server_setup`
-- * plugins register common options applied to all servers using
--   `ucw.lsp.setup_common`
-- * `ucw.lsp.on_server_ready` is called for each server
-- * options from nvim-lsp-installer is used as a bases
-- * options from setup_common is merged in
-- * additional options from user modules (`ucw.lsp.lang.*`) will be merged in
-- * plugin optinally can take care of eventually calling
--   lspconfig setup for a specific server
-- * or nvim-lsp-installer will call lspconfig setup
-- ]]
local M = {}

function M.setup()
  require('ucw.lsp.lsp-notify').setup()
end

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

local function get_server(name)
  local server_setup = enhance_server_opts[name] or default_server_setup
  local server_opts = {}

  -- options from lang module
  local present, lang_opts = pcall(require, 'ucw.lsp.lang.' .. name)
  if present then
    server_opts = vim.tbl_deep_extend('force', server_opts, lang_opts)
  end

  -- TODO merge in workspace options
  return server_opts, server_setup
end

-- Each server's option is sourced from
-- * common options
-- * server specific options from plugins
-- * server specific options from lang module
-- * TODO: workspace specific options if any
function M.on_server_ready(server)
  local server_opts, server_setup = get_server(server.name)
  server_setup(server, vim.tbl_deep_extend('force', common_opts, server_opts))
end

return M
