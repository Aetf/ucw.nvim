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
-- * options from setup_common is used as a basis
-- * options from nvim-lsp-installer is merged in
-- * additional options from user modules (`ucw.lsp.lang.*`) will be merged in
-- * additional options from workspace (`.vscode/settings.json`) will be merged in
-- * plugin optinally can take care of eventually calling
--   lspconfig setup for a specific server
-- * or nvim-lsp-installer will call lspconfig setup
-- ]]
local M = {}
local au = require('au')

local vscode = require('ucw.lsp.vscode')
local opts = require('ucw.lsp.options')

-- reexport a few
M.setup_common = opts.setup_common
M.custom_server_setup = opts.custom_server_setup

local function on_new_config(new_config, root_dir)
  vscode.on_new_config_workdir(new_config, root_dir)

  local root_dir_name = vim.fn.fnamemodify(root_dir, ':p:~')
  vim.notify(string.format('Enabeld on: %s', root_dir_name), vim.log.levels.INFO, {
    title = string.format('LSP [%s]', new_config.name)
  })
end

local function on_attach(_, _)
  -- au.CursorHold = {
  --   '<buffer>',
  --   vim.diagnostic.open_float,
  -- }
end

function M.setup()
  --require('ucw.lsp.lsp-notify').setup()

  local lspconfig = require('lspconfig')
  M.setup_common({
    -- hook on_new_config to inject workspace specific settings
    -- always chain default config's on_new_config
    on_new_config = lspconfig.util.add_hook_after(lspconfig.util.default_config.on_new_config, on_new_config),
    -- some functionalities enabled only after attaching a lsp server
    on_attach = lspconfig.util.add_hook_after(lspconfig.util.default_config.on_attach, on_attach)
  })

  -- hook on server ready to provide our settings
  local lsp_installer = require("nvim-lsp-installer")
  lsp_installer.on_server_ready(opts.on_server_ready)

  vim.notify('ucw.lsp setup ready ')
end

return M
