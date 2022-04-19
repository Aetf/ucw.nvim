-- [[
-- LSP integration framework that coordinates the setup between
-- nvim-lsp-installer, nvim-lspconfig, various enhance plugins and
-- any user custom language settings.
-- ]]
local M = {}
local au = require('au')

local hooks = require('ucw.lsp.hooks')

-- reexport a few
M.register_server_setup = hooks.register_server_setup
M.register_on_server_ready = hooks.register_on_server_ready
M.register_on_new_config = hooks.register_on_new_config
M.register_on_attach = hooks.register_on_attach

local function on_new_config(new_config, root_dir)
  local root_dir_name = vim.fn.fnamemodify(root_dir, ':p:~')
  vim.notify(string.format('Enabled on: %s', root_dir_name), vim.log.levels.INFO, {
    title = string.format('LSP [%s]', new_config.name)
  })
  -- vim.notify(string.format('LSP [%s] config: %s', new_config.name, vim.inspect(new_config)))
end

local function on_attach(client, bufnr)
  -- au.CursorHold = {
  --   '<buffer>',
  --   vim.diagnostic.open_float,
  -- }
  --
  if client.resolved_capabilities.goto_definition == true then
    vim.api.nvim_buf_set_option(bufnr, "tagfunc", "v:lua.vim.lsp.tagfunc")
  end

  if client.resolved_capabilities.document_formatting == true then
    vim.api.nvim_buf_set_option(bufnr, "formatexpr", "v:lua.vim.lsp.formatexpr()")
  end
end

function M.setup()
  --require('ucw.lsp.lsp-notify').setup()
  require('ucw.lsp.vscode').setup()

  hooks.register_on_new_config('.*', on_new_config)
  hooks.register_on_attach('.*', on_attach)

  -- hook on server ready to provide our settings
  local lsp_installer = require("nvim-lsp-installer")
  lsp_installer.on_server_ready(hooks.do_on_server_ready)
end

return M
