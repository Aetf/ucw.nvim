local M = {}

-- bootstrap lazy.nvim itself (clone on first run)
local function bootstrap_lazy()
  local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
      'git', 'clone', '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git',
      '--branch=stable',
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

function M.boot()
  local targets = require('ucw.targets')

  -- Disable unused plugin hosts given we have lua now
  vim.g.loaded_python3_provider = 0
  vim.g.loaded_python_provider = 0
  vim.g.loaded_ruby_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_node_provider = 0

  -- The normal options and tweaks that doesn't rely on plugins
  require('ucw.options')
  require('ucw.builtin-plugins')
  require('ucw.keys')
  require('ucw.extras')

  -- Per-client LSP buffer setup (keymaps, inlay hints, codelens, .vscode
  -- settings). Eager on purpose, and it costs exactly one autocmd: clients
  -- arrive from two directions - `vim.lsp.enable()` once nvim-lspconfig is
  -- loaded by filetype, and rustaceanvim starting its own on `ft=rust` without
  -- nvim-lspconfig ever loading at all. Hanging this off either one leaves the
  -- other with no keymaps and no hints.
  require('ucw.lsp.attach').setup()

  bootstrap_lazy()
  require('lazy').setup({
    spec = {
      { import = 'ucw.plugins' },
      { import = 'ucw.plugins.user' },
    },
    install = { colorscheme = { 'base16-eighties' } },
    change_detection = { notify = false },
  })

  if targets.is_gui() then
    require('ucw.gui').setup()
  end
end

return M
