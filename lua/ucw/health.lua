-- `:checkhealth ucw`.
--
-- This module owns no policy; it reports. It exists because of one deliberate
-- limitation and one comparison nobody was making.
--
-- The limitation: binaries are resolved through `PATH`, with Mason appended
-- rather than prepended (lua/ucw/plugins/mason.lua), so whatever project the
-- session was started in wins. `PATH` belongs to the process, not to the
-- buffer - so a session started somewhere else, or one that `:cd`s into a
-- second project, silently gets Mason's compatibility floor instead. That is
-- accepted on one condition: that it is *visible*. Printing the path each
-- declared binary actually resolved to is the whole of that condition.
--
-- The comparison: the set of binaries this config declares, against the set
-- Mason has installed. Both directions had gone wrong unnoticed - an Oct 2022
-- `rust-analyzer` sat installed and declared by nothing for four years, while
-- `prettier` is declared and absent - and neither runtime installer ever
-- updates a package it already installed, so "installed, and years old" is a
-- third state that needs an owner.
--
-- docs/design/phase6.5-binary-deps.md §2.4.
local M = {}

local health = vim.health

-- Where Mason puts the bin directory it adds to `PATH`
-- (mason-core/installer/InstallLocation.lua: `:bin()`, consumed by
-- `:set_env()`). Asking Mason rather than rebuilding the path from settings
-- keeps this honest if upstream moves it.
local function mason_bin_dir()
  return require('mason-core.installer.InstallLocation').global():bin()
end

-- Every section below needs two modules: Mason's registry, and the
-- registry-derived `lspconfig name -> package name` mapping that
-- mason-lspconfig owns. Both are lazy, so a health check has to ask; the
-- second is also `cond`-gated off under the embedded targets, where its
-- absence is the correct state and not a failure.
--
-- Availability is therefore *reported*, not assumed - and not re-derived from
-- `ucw.targets` either. Asking "is this a full UI?" here would make this file
-- a second owner of a rule the specs already own, which is exactly the seam
-- that made `<leader>lf` throw `module 'conform' not found` under firenvim
-- (docs/design/phase6-acceptance-review.md R1).
---@return table? registry mason-registry
---@return table? mappings mason-lspconfig.mappings
local function load_mason()
  pcall(function()
    require('lazy').load { plugins = { 'mason.nvim', 'mason-lspconfig.nvim' } }
  end)
  local has_registry, registry = pcall(require, 'mason-registry')
  local has_mappings, mappings = pcall(require, 'mason-lspconfig.mappings')
  if has_registry and has_mappings then
    return registry, mappings
  end
end

-- The two declaration sites, read rather than restated. Adding a server to
-- `ucw.lsp.servers` or a tool to mason-tool-installer's `ensure_installed` is
-- picked up here with no third list to keep in step - which is the same rule
-- §2.1 applies to the config itself.
--
-- The `lspconfig name -> Mason package name` mapping is registry data
-- (`lua_ls` -> `lua-language-server`, `jsonls` -> `json-lsp`, ...), owned by
-- mason-lspconfig; it is empty until the registry has been refreshed, so a
-- server that maps to nothing is reported rather than skipped.
---@return table<string, string> package name -> a human-readable declaration site
---@return string[] lspconfig names that no Mason package could be found for
local function declared_packages(mappings)
  local mapping = mappings.get_mason_map().lspconfig_to_package
  local declared, unmapped = {}, {}

  for _, server in ipairs(require('ucw.lsp').server_names()) do
    local package = mapping[server]
    if package then
      declared[package] = ('ucw.lsp.servers (%s)'):format(server)
    else
      table.insert(unmapped, server)
    end
  end

  -- The lazy spec, not the loaded plugin: the spec is the declaration, and it
  -- is readable whether or not mason-tool-installer has reached its `VeryLazy`
  -- trigger yet. tests/test_lsp.lua reads mason-lspconfig's the same way.
  local spec = require('lazy.core.config').plugins['mason-tool-installer.nvim']
  for _, package in ipairs(vim.tbl_get(spec or {}, 'opts', 'ensure_installed') or {}) do
    declared[package] = 'mason-tool-installer (ensure_installed)'
  end

  table.sort(unmapped)
  return declared, unmapped
end

-- §2.4.1. The line that would have shown `rust-analyzer` coming from Mason
-- since 2022, and the line that shows a project's pin *not* being picked up in
-- a session started from the wrong place.
local function check_resolution(registry, declared)
  health.start('ucw: where declared binaries resolve to')

  local mason_bin = mason_bin_dir()
  local path = vim.split(vim.env.PATH or '', ':', { plain = true })
  local position
  for index, entry in ipairs(path) do
    if entry == mason_bin then
      position = index
    end
  end

  if position == nil then
    health.warn(("Mason's bin directory is not on PATH at all (%s)"):format(mason_bin), {
      'Mason has not been loaded in this session yet, or `PATH = "skip"` is set.',
    })
  elseif position == #path then
    health.ok(('Mason is last on PATH - the floor, as intended (%s)'):format(mason_bin))
  else
    health.warn(('Mason is #%d of %d on PATH, not last (%s)'):format(position, #path, mason_bin), {
      'Something prepended it after `mason.setup { PATH = "append" }` ran; project pins for these binaries will lose.',
    })
  end

  -- Sorted by binary name rather than by package: this is a report about what
  -- a `command = 'stylua'` somewhere will actually execute, and that is the
  -- name the caller writes.
  local rows = {}
  for package, site in pairs(declared) do
    local ok, pkg = pcall(registry.get_package, package)
    for binary in pairs(ok and pkg.spec.bin or {}) do
      table.insert(rows, { binary = binary, package = package, site = site })
    end
  end
  table.sort(rows, function(a, b)
    return a.binary < b.binary
  end)

  for _, row in ipairs(rows) do
    local resolved = vim.fn.exepath(row.binary)
    if resolved == '' then
      health.warn(('%s: not on PATH (declared by %s)'):format(row.binary, row.site))
    elseif vim.startswith(resolved, mason_bin .. '/') then
      health.ok(('%s: %s (Mason, the floor)'):format(row.binary, resolved))
    else
      health.ok(('%s: %s (ahead of Mason on PATH)'):format(row.binary, resolved))
    end
  end
end

-- §2.4.2. Three states, because all three have been real here.
local function check_declared_vs_installed(registry, declared, unmapped)
  health.start('ucw: declared versus installed')

  for _, server in ipairs(unmapped) do
    health.error(('%s is enabled in ucw.lsp.servers but maps to no Mason package'):format(server), {
      'Nothing installs that server, and it never attaches - `:MasonLog` and `:checkhealth mason`.',
      'If the registry could not be fetched at all, every server says this at once.',
    })
  end

  local names = vim.tbl_keys(declared)
  table.sort(names)
  for _, package in ipairs(names) do
    local ok, pkg = pcall(registry.get_package, package)
    local site = declared[package]
    if not ok then
      health.error(('%s: no such Mason package (declared by %s)'):format(package, site))
    elseif not pkg:is_installed() then
      health.warn(('%s: declared by %s, not installed'):format(package, site), {
        'Run `:MasonToolsInstall`, or `:MasonInstall ' .. package .. '`.',
        'If it fails, `:checkhealth mason` lists the system prerequisites it needs.',
      })
    else
      local installed = pkg:get_installed_version()
      local latest = pkg:get_latest_version()
      if installed == nil then
        health.warn(('%s: installed, version unknown'):format(package), {
          'The install receipt predates the version field, which makes it very old.',
          'Neither installer updates an installed package: `:MasonInstall ' .. package .. '` to replace it.',
        })
      elseif installed ~= latest then
        health.warn(('%s: %s installed, registry has %s'):format(package, installed, latest), {
          'Nothing updates this by itself (`auto_update = false`, and mason-lspconfig behaves the same).',
          'Deliberately: swapping a language server under a running editor is worse than an old one.',
        })
      else
        health.ok(('%s: %s'):format(package, installed))
      end
    end
  end

  for _, package in ipairs(registry.get_installed_package_names()) do
    if not declared[package] then
      health.warn(('%s: installed, declared by nothing'):format(package), {
        'A fresh machine would not have it - so whatever depends on it is broken there and works here.',
        'Declare it (ucw.lsp.servers, or mason-tool-installer for install-only) or `:MasonUninstall '
          .. package
          .. '`.',
      })
    end
  end
end

-- §2.4.3. The probe in lua/ucw/plugins/treesitter.lua stays where it is: it
-- exists to suppress a per-boot error, which a health check cannot do. This
-- says the same thing where someone is looking for it.
local function check_tree_sitter()
  health.start('ucw: tree-sitter CLI')
  local resolved = vim.fn.exepath('tree-sitter')
  if resolved ~= '' then
    health.ok(('%s'):format(resolved))
  else
    health.warn('not on PATH - nvim-treesitter cannot compile or update parsers', {
      'Only the parsers already compiled under `<data>/site/parser` work; new ones fail.',
      'Everything on PATH is fair game, e.g. `mise use -g tree-sitter@latest` or `cargo install tree-sitter-cli`.',
    })
  end
end

function M.check()
  local registry, mappings = load_mason()
  if not (registry and mappings) then
    health.start('ucw: binaries')
    health.info(table.concat({
      'Mason is not available in this context, so none of the binary checks can run.',
      'That is expected under the embedded targets (firenvim, vscode-neovim), where the',
      'Mason specs are `cond`-gated off - see lua/ucw/targets.lua.',
    }, ' '))
    check_tree_sitter()
    return
  end

  -- Before anything reads the registry, and not once per section. Two things
  -- need it and only one of them is obvious: `get_latest_version()` is
  -- unanswerable without it, and so is the `lspconfig name -> package name`
  -- mapping - mason-lspconfig memoizes that from `get_all_package_specs()`,
  -- which is *empty* until a refresh has happened, so asking too early gets a
  -- confident `nil` for every server rather than an error
  -- (docs/design/phase6.5-binary-deps.md §3.4). Written the other way round
  -- first: in a test child with a cold registry every declared server reported
  -- "maps to no Mason package", and it only looked correct because the second
  -- case in the file reused the first one's download.
  --
  -- The callback-less form blocks, which is right here and nowhere else
  -- (mason-registry/init.lua).
  registry.refresh()

  local declared, unmapped = declared_packages(mappings)
  check_resolution(registry, declared)
  check_declared_vs_installed(registry, declared, unmapped)
  check_tree_sitter()

  -- §2.4.4. `:checkhealth mason` already probes every system prerequisite -
  -- curl, unzip, tar, node, npm, python, java, cargo and more - and upstream
  -- maintains that list. A second, smaller copy of it here would only ever be
  -- more wrong.
  health.start('ucw: see also')
  health.info('`:checkhealth mason` for the system prerequisites Mason needs in order to install anything.')
end

return M
