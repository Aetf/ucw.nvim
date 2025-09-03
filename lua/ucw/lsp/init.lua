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

function setup_codelens_refresh(client, bufnr)
  local status_ok, codelens_supported = pcall(function()
    return client.supports_method("textDocument/codeLens")
  end)
  if not status_ok or not codelens_supported then
    return
  end
  local group = "lsp_code_lens_refresh"
  local cl_events = { "BufEnter", "InsertLeave" }
  local ok, cl_autocmds = pcall(vim.api.nvim_get_autocmds, {
    group = group,
    buffer = bufnr,
    event = cl_events,
  })
  if ok and #cl_autocmds > 0 then
      return
  end
  vim.api.nvim_create_augroup(group, { clear = false })
  vim.api.nvim_create_autocmd(cl_events, {
    group = group,
    buffer = bufnr,
    callback = vim.lsp.codelens.refresh,
  })
  vim.lsp.codelens.refresh( { bufnr = bufnr })
end

local function setup_keymap(client, bufnr)
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
  hooks.register_on_attach('.*', setup_keymap)
  hooks.register_on_attach('.*', setup_codelens_refresh)

end

function M.activate()
  hooks.activate()
end

return M
