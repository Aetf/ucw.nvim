local M = {}

-- bootstrap lazy.nvim itself (clone on first run)
-- The commit `lazy-lock.json` pins lazy.nvim itself to, or nil if there is no
-- lockfile yet (a first boot on a fresh checkout).
local function locked_lazy_commit()
  local ok, lock = pcall(function()
    local path = vim.fs.joinpath(vim.fn.stdpath('config'), 'lazy-lock.json')
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  local entry = ok and type(lock) == 'table' and lock['lazy.nvim'] or nil
  return type(entry) == 'table' and type(entry.commit) == 'string' and entry.commit or nil
end

local function bootstrap_lazy()
  local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    -- Checked out at the commit in the lockfile, not at whatever `stable`
    -- points to today. lazy.nvim manages itself like any other plugin and
    -- records its own commit in `lazy-lock.json`, but it is the one plugin it
    -- cannot *install* - so cloning a moving branch made every fresh install
    -- write a different commit than the one checked in, which is the CI
    -- "lazy-lock.json did not drift" gate failing on a lockfile nobody
    -- touched. Updating lazy.nvim goes through `:Lazy update` and lands in the
    -- lockfile, same as everything else.
    vim.fn.system { 'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git', lazypath }
    local commit = locked_lazy_commit()
    if commit then
      vim.fn.system { 'git', '-C', lazypath, 'checkout', '--detach', commit }
    else
      vim.fn.system { 'git', '-C', lazypath, 'checkout', '--detach', 'origin/stable' }
    end
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
  require('lazy').setup {
    spec = {
      { import = 'ucw.plugins' },
      { import = 'ucw.plugins.user' },
    },
    install = { colorscheme = { 'base16-eighties' } },
    change_detection = { notify = false },
  }

  if targets.is_gui() then
    require('ucw.gui').setup()
  end
end

return M
