-- [[
-- LSP integration framework that coordinates the setup between
-- nvim-lsp-installer, nvim-lspconfig, various enhance plugins and
-- any user custom language settings.
-- ]]
local M = {}
local au = require('au')

local hooks = require('ucw.lsp.hooks')

-- reexport a few
M.register_on_server_setup = hooks.register_on_server_setup
M.register_on_new_config = hooks.register_on_new_config
M.register_on_attach = hooks.register_on_attach

local function on_new_config(new_config, root_dir)
  local root_dir_name = vim.fn.fnamemodify(root_dir, ':p:~')
  vim.notify(string.format('Enabled on:\n%s', root_dir_name), vim.log.levels.INFO, {
    title = string.format('LSP [%s]', new_config.name)
  })
end

local function on_attach(client, bufnr)
  -- integrate with native vim
  if client.resolved_capabilities.goto_definition == true then
    vim.api.nvim_buf_set_option(bufnr, "tagfunc", "v:lua.vim.lsp.tagfunc")
  end

  if vim.api.nvim_buf_get_option(bufnr, "formatexpr") == "" then
    if client.resolved_capabilities.document_formatting == true then
      vim.api.nvim_buf_set_option(bufnr, "formatexpr", "v:lua.vim.lsp.formatexpr()")
    end
  end

  -- register a few buffer local shortcuts
  local wk = require('which-key')
  wk.register({
    ['<M-CR>'] = { [[<cmd>lua vim.lsp.buf.code_action()<cr>]], "Code actions" },
    ['<M-S-CR>'] = { [[<cmd>lua vim.lsp.buf.range_code_action()<cr>]], "Range code actions" },
    g = {
      ['0'] = { [[<cmd>Telescope lsp_document_symbols<cr>]], "Symbols in the current buffer"},
      W = { [[<cmd>Telescope lsp_workspace_symbols<cr>]], "Symbols in the current workspace"},
      e = { [[<cmd>Telescope diagnostics<cr>]], "Diagnostics for current buffer"},
      D = { [[<cmd>Telescope lsp_implementations<cr>]], "Go to implementation"},
      d = { [[<cmd>Telescope lsp_definitions<cr>]], "Go to definition"},
      t = { [[<cmd>Telescope lsp_type_definitions<cr>]], "Go to type definition"},
      H = { [[<cmd>lua vim.lsp.declaration()<cr>]], "Go to declaration"},
      r = { [[<cmd>Telescope lsp_references<cr>]], "Find references"},
    },
    ['<c-k>'] = { '<cmd>lua vim.diagnostic.open_float()<cr>', "Show diagnostics on the current line" },
    ['<M-S-r>'] = { [[<cmd>lua vim.lsp.buf.rename()<cr>]], "Rename the symbol under cursor" },
  }, { buffer = bufnr })

end

function M.config()
  hooks.install()

  require('ucw.lsp.vscode').install()

  hooks.register_on_new_config('.*', on_new_config)
  hooks.register_on_attach('.*', on_attach)
end

return M
