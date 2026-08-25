-- Integration coverage for the Phase 3 LSP subsystem.
--
-- The point of this file is stated plainly because it shapes every assertion
-- below: this configuration used to work and then quietly stopped, one Neovim
-- release at a time. `ucw.lsp.hooks` fanned out through two monkey-patched
-- nvim-lspconfig internals; when servers started coming up through native
-- `vim.lsp.enable()` instead, two of the three hooks fired **zero** times and
-- took nine per-server modules, the `.vscode/settings.json` initial load, ufo's
-- folding capability and cmp's completion capabilities down with them. Nothing
-- errored. So the tests here assert *effects* - the merged config, the
-- capabilities actually advertised, the keymaps actually present on an attached
-- buffer - rather than that a file exists or a function was called.
--
-- What is deliberately not here: nothing starts a real language server. The
-- test child gets a scratch XDG_DATA_HOME, so Mason has installed nothing into
-- it, and a test that needs `lua-language-server` on disk would either be
-- skipped in CI or spend minutes downloading. Attach behaviour is covered with
-- an in-process fake server instead (see `new_fake_server` below), which is
-- both deterministic and a better test of the actual claim - that `LspAttach`
-- reaches clients nobody started through `vim.lsp.enable()`, the way
-- rustaceanvim starts its own.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- A language server that lives entirely inside the test child. `cmd` may be a
-- function returning an RPC object (runtime/lua/vim/lsp/client.lua:485), which
-- is all `vim.lsp.start` needs - no binary, no subprocess, no waiting.
local FAKE_SERVER = [[
  function _G.new_fake_server(capabilities)
    _G.fake_notifications = {}
    return function(dispatchers)
      local closing, id = false, 0
      return {
        request = function(method, _, callback)
          id = id + 1
          if method == 'initialize' then
            callback(nil, { capabilities = capabilities or {}, serverInfo = { name = 'fake' } })
          else
            callback(nil, nil)
          end
          return true, id
        end,
        notify = function(method, params)
          table.insert(_G.fake_notifications, { method = method, params = params })
          if method == 'exit' then dispatchers.on_exit(0, 15) end
          return true
        end,
        is_closing = function() return closing end,
        terminate = function() closing = true end,
      }
    end
  end
]]

-- LSP is `ft`-triggered, and the child opens no files, so nothing is loaded
-- until a test asks for it. Force-loading nvim-lspconfig runs its `config`,
-- i.e. `ucw.lsp.setup()`: attach handlers registered, `vim.lsp.enable()`
-- called. That is deterministic in a way that opening a .lua file is not (that
-- would also try to spawn a lua-language-server the child does not have).
local function load_lsp()
  child.lua([[require('lazy').load({ plugins = { 'nvim-lspconfig' } })]])
end

T['activation'] = new_set()

-- Goal 1 for the LSP subsystem: nothing that produces an attached client is on
-- the startup path. Measured on the finished implementation, the whole `ft`
-- trigger is ~3 ms; the two expensive plugins are deliberately elsewhere -
-- mason-lspconfig on VeryLazy, lsp-progress on LspAttach.
T['activation']['the LSP hot path is not loaded at startup'] = function()
  for _, name in ipairs { 'nvim-lspconfig', 'rustaceanvim', 'clangd_extensions.nvim', 'lsp-progress.nvim' } do
    eq(
      { name, child.lua_get(([[require('lazy.core.config').plugins[%q]._.loaded ~= nil]]):format(name)) },
      { name, false }
    )
  end
end

-- mason-lspconfig *is* expected to come up on VeryLazy - it only exists to run
-- `ensure_installed`. What must not happen is it doing that inside a test:
-- mason skips installation when no UI is attached, and the mini.test child has
-- none. If that ever changes, the suite would start downloading nine language
-- servers per run, so assert the precondition rather than trusting it.
T['activation']['ensure_installed cannot fire inside the test child'] = function()
  eq(child.lua_get([[#vim.api.nvim_list_uis()]]), 0)
  eq(child.lua_get([[vim.fn.glob(vim.fn.stdpath('data') .. '/mason/packages/*', false, true)]]), {})
end

T['activation']['the ft trigger is exactly ucw.lsp.filetypes()'] = function()
  -- If these drift, opening a supported file stops bringing LSP up at all -
  -- silently, because there is nothing left to error.
  eq(
    child.lua_get([[require('lazy.core.config').plugins['nvim-lspconfig'].ft]]),
    child.lua_get([[require('ucw.lsp').filetypes()]])
  )
end

T['activation']['enabling happens against the explicit server list'] = function()
  eq(child.lua_get([[next(vim.lsp._enabled_configs) == nil]]), true)
  load_lsp()

  local enabled = child.lua_get([[
        (function()
          -- `vim.lsp.is_enabled` is the public query; the table is how to get
          -- the whole set, which is the point here - "no surprise auto-enables"
          local names = vim.tbl_keys(vim.lsp._enabled_configs)
          table.sort(names)
          return names
        end)()
    ]])
  eq(enabled, child.lua_get([[require('ucw.lsp').server_names()]]))
end

-- The duplicate rust-analyzer, at its cause. mason-lspconfig's
-- `automatic_enable` default enables every *installed* server, which started a
-- second `rust_analyzer` next to the one rustaceanvim owns; both advertised
-- inlayHintProvider, so every hint rendered twice.
T['activation']['mason-lspconfig does not auto-enable anything'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['mason-lspconfig.nvim'].opts.automatic_enable]]), false)
  load_lsp()
  eq(child.lua_get([[vim.lsp.is_enabled('rust_analyzer')]]), false)
end

-- `mason.setup()` is what puts `<data>/mason/bin` on PATH, and every server
-- binary this config runs lives there. A spec that starts a language server
-- without depending on mason is relying on something else having loaded it
-- first: rustaceanvim did exactly that, and only worked because it happens to
-- `require('mason-registry')` while probing for codelldb (acceptance review
-- P4). Without the PATH edit it starts no client and says nothing.
T['activation']['every spec that starts a server depends on mason'] = function()
  local missing = child.lua_get([[
        (function()
          local plugins = require('lazy.core.config').plugins
          local bad = {}
          for _, name in ipairs({ 'nvim-lspconfig', 'rustaceanvim' }) do
            local deps = plugins[name] and plugins[name].dependencies or {}
            if not vim.tbl_contains(deps, 'mason.nvim') then
              table.insert(bad, name .. ': ' .. vim.inspect(deps, { newline = ' ', indent = '' }))
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(missing, {})
end

T['activation']['ensure_installed tracks the server list'] = function()
  eq(
    child.lua_get([[require('lazy.core.config').plugins['mason-lspconfig.nvim'].opts.ensure_installed]]),
    child.lua_get([[require('ucw.lsp').server_names()]])
  )
end

T['config layering'] = new_set()

-- `after/lsp/` only wins over nvim-lspconfig's `lsp/` because
-- `~/.config/nvim/after` sorts last in the runtimepath. If that ever stops
-- being true, every per-server setting below silently reverts to upstream's.
T['config layering']['our settings merge over nvim-lspconfig, keeping its cmd'] = function()
  load_lsp()
  eq(child.lua_get([[vim.lsp.config['lua_ls'].cmd]]), { 'lua-language-server' })
  eq(child.lua_get([[vim.lsp.config['lua_ls'].settings.Lua.runtime.version]]), 'LuaJIT')
  eq(child.lua_get([[vim.lsp.config['lua_ls'].settings.Lua.diagnostics.globals]]), { 'vim', 'MiniIcons' })
  -- inherited, not restated
  eq(child.lua_get([[vim.lsp.config['lua_ls'].filetypes]]), { 'lua' })
end

-- List-valued fields are replaced wholesale rather than appended to, so an
-- `after/lsp/` file that sets `root_markers` has to repeat everything it still
-- wants. Getting this wrong is invisible: markers just stop matching.
T['config layering']['marksman finds Obsidian vaults and still finds git repos'] = function()
  load_lsp()
  eq(child.lua_get([[vim.lsp.config['marksman'].root_markers]]), { { '.marksman.toml', '.obsidian' }, '.git' })
end

-- Function fields do NOT compose: the highest layer that defines one wins and
-- upstream's is dropped. Everything in after/lsp/ is therefore tables only -
-- and these two are what would break first if that slipped.
T['config layering']['upstream function fields survive our overrides'] = function()
  load_lsp()
  -- ltex maps bib -> bibtex, tex -> latex; losing it checks LaTeX as prose
  eq(child.lua_get([[type(vim.lsp.config['ltex_plus'].get_language_id)]]), 'function')
  -- clangd's on_attach/on_init carry switch_source_header and encoding setup
  eq(child.lua_get([[type(vim.lsp.config['clangd'].on_attach)]]), 'function')
  eq(child.lua_get([[type(vim.lsp.config['clangd'].on_init)]]), 'function')
  eq(child.lua_get([[type(vim.lsp.config['texlab'].on_attach)]]), 'function')
end

T['config layering']['no after/lsp/ file defines a function field'] = function()
  local offenders = child.lua_get([[
        (function()
          local dir = vim.fn.stdpath('config') .. '/after/lsp'
          local bad = {}
          for _, path in ipairs(vim.fn.glob(dir .. '/*.lua', false, true)) do
            local cfg = loadfile(path)()
            for k, v in pairs(cfg) do
              if type(v) == 'function' then
                table.insert(bad, vim.fn.fnamemodify(path, ':t') .. ': ' .. k)
              end
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(offenders, {})
end

T['config layering']['every after/lsp/ file names a server we run'] = function()
  local unknown = child.lua_get([[
        (function()
          local servers = require('ucw.lsp.servers')
          local bad = {}
          for _, path in ipairs(vim.fn.glob(vim.fn.stdpath('config') .. '/after/lsp/*.lua', false, true)) do
            local name = vim.fn.fnamemodify(path, ':t:r')
            if servers[name] == nil then table.insert(bad, name) end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(unknown, {})
end

-- `~/.config/nvim/after` beats every plugin's `lsp/`, but NOT a plugin's own
-- `after/lsp/` - lazy.nvim inserts those after it (lua/lazy/core/loader.lua:467).
-- mason-lspconfig really does ship one; it only holds `omnisharp_mono.lua`
-- today. If a plugin ever ships a file for a server we configure, our settings
-- lose and nothing says so.
T['config layering']['no plugin shadows our after/lsp/ files'] = function()
  load_lsp()
  local shadowed = child.lua_get([[
        (function()
          local servers = require('ucw.lsp.servers')
          local ours = vim.fn.stdpath('config')
          local bad = {}
          for _, path in ipairs(vim.api.nvim_get_runtime_file('after/lsp/*.lua', true)) do
            local name = vim.fn.fnamemodify(path, ':t:r')
            if servers[name] ~= nil and not vim.startswith(path, ours) then
              table.insert(bad, name .. ' <- ' .. path)
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(shadowed, {})
end

-- servers.lua is duplicated information by construction: lazy.nvim needs the
-- filetype list before nvim-lspconfig is on the runtimepath, so it cannot be
-- derived from it. This is the assertion that keeps the duplication honest -
-- and it is exactly the kind of drift an upstream release introduces.
T['config layering']['servers.lua filetypes match the resolved configs'] = function()
  load_lsp()
  local mismatches = child.lua_get([[
        (function()
          local bad = {}
          for name, fts in pairs(require('ucw.lsp.servers')) do
            local actual = vim.lsp.config[name] and vim.lsp.config[name].filetypes
            if not vim.deep_equal(fts, actual) then
              table.insert(bad, ('%s: servers.lua=%s config=%s'):format(
                name, vim.inspect(fts, { newline = ' ', indent = '' }),
                vim.inspect(actual, { newline = ' ', indent = '' })))
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(mismatches, {})
end

T['capabilities'] = new_set()

-- Two independent plugins contribute to `vim.lsp.config('*')` and neither knows
-- about the other; they only compose because capabilities is a table and both
-- run before the first `vim.lsp.enable()`. Both contributions have silently
-- gone missing before - that is the bug Phase 2 found and the one ufo still
-- had.
T['capabilities']['blink and ufo both reach every server'] = function()
  load_lsp()
  local caps = child.lua_get([[vim.lsp.config['*'].capabilities]])
  -- nvim-ufo
  eq(caps.textDocument.foldingRange.lineFoldingOnly, true)
  -- blink.cmp
  eq(caps.textDocument.completion.completionItem.snippetSupport, true)
  -- Neovim's own defaults, which blink drops unless include_nvim_defaults=true
  eq(caps.textDocument.signatureHelp ~= nil, true)
end

T['capabilities']['basedpyright asks for client-side file watching'] = function()
  load_lsp()
  -- measured: the global default is `false`, so this is a real change and not
  -- a restatement of what Neovim already advertises
  eq(child.lua_get([[vim.lsp.config['*'].capabilities.workspace.didChangeWatchedFiles.dynamicRegistration]]), false)
  eq(
    child.lua_get([[vim.lsp.config['basedpyright'].capabilities.workspace.didChangeWatchedFiles.dynamicRegistration]]),
    true
  )
end

-- Every client has to agree on what a column is. Offered the choice,
-- basedpyright takes utf-16 and ruff takes utf-8 - and every Python buffer has
-- both, which `:checkhealth vim.lsp` flags (second-round review, Q3). Pinning
-- the one encoding the spec requires every server to support is its own advice.
T['capabilities']['every server is pinned to one position encoding'] = function()
  load_lsp()
  eq(child.lua_get([[vim.lsp.config['*'].capabilities.general.positionEncodings]]), { 'utf-16' })
  -- and it survives the merge into a server that has its own capabilities
  eq(child.lua_get([[vim.lsp.config['basedpyright'].capabilities.general.positionEncodings]]), { 'utf-16' })
end

T['attach'] = new_set()

local function start_fake(name, capabilities, root_dir, opts)
  if not (opts and opts.no_lspconfig) then
    load_lsp()
  end
  child.lua(FAKE_SERVER)
  return child.lua_get(([[
        (function()
          vim.cmd('enew!')
          return vim.lsp.start({
            name = %q,
            cmd = _G.new_fake_server(%s),
            root_dir = %s,
          })
        end)()
    ]]):format(name, capabilities or '{}', root_dir and ('%q'):format(root_dir) or 'nil'))
end

-- ruff answers `textDocument/hover` with nothing at nearly every position, and
-- `vim.lsp.buf.hover()` notifies "No information available" once per empty
-- answer - so every `K` in a python buffer drew basedpyright's float and ruff's
-- "found nothing" next to each other. Asserted on a fake client *named* ruff,
-- because what decides this is the name in the attach handler, not anything
-- ruff's binary does; both halves are here because taking the capability from
-- every client would be the same bug with the sign flipped.
T['attach']["ruff's hover is declined, and only ruff's"] = function()
  start_fake('ruff', '{ hoverProvider = true }')
  eq(child.lua_get([[vim.lsp.get_clients({ name = 'ruff' })[1].server_capabilities.hoverProvider]]), false)
  eq(child.lua_get([[vim.lsp.get_clients({ name = 'ruff' })[1]:supports_method('textDocument/hover')]]), false)

  start_fake('basedpyright', '{ hoverProvider = true }')
  eq(child.lua_get([[vim.lsp.get_clients({ name = 'basedpyright' })[1].server_capabilities.hoverProvider]]), true)
end

-- The claim the whole "rustaceanvim is not a special case" argument rests on:
-- attach behaviour reaches a client that never went through `vim.lsp.enable()`.
T['attach']['handlers fire for a client started outside vim.lsp.enable'] = function()
  local id = start_fake('faketest')
  eq(id ~= vim.NIL and id ~= nil, true)

  -- `definitions` became a picker action in Phase 5, so its right-hand side
  -- is a Lua callback rather than an ex-command string. `maparg().rhs` is
  -- empty for those, which is indistinguishable from the not-actually-mapped
  -- state that the Phase 3 acceptance review's P3 turned out to be - hence
  -- asserting on `callback` rather than on an empty `rhs`.
  local map = child.lua_get([[
        (function()
          local m = vim.fn.maparg('gd', 'n', false, true)
          return { buffer = m.buffer, has_callback = m.callback ~= nil, desc = m.desc }
        end)()
    ]])
  eq(map.buffer, 1)
  eq(map.has_callback, true)
  eq(map.desc, 'Go to definition')
end

-- Phase 9 (D1)'s buffer-local instrument (design doc §6): the keymap
-- snapshot script reads only the global mapping table, so the post-attach
-- buffer-local set - the largest single chunk of the Phase 9 redesign - is
-- invisible to it. Both halves are asserted exactly: the keys that exist
-- (desc resolved through ucw.lsp.actions), and the seven keys D1 deleted
-- staying deleted - re-introducing any of those would shadow a native motion
-- (`ge`, `g0`, `gt`) or sit on the native `gr*` prefix again. `[r`/`]r`
-- (Phase 9.5, T6) join the positive half: they are buffer-local for the same
-- reason, and a reference walk with nothing bound to it is the shape of
-- feature this file exists to keep honest.
T['attach']['the buffer-local key set is exactly the D1 set'] = function()
  start_fake('faketest')
  for lhs, want in pairs {
    ['gd'] = 'Go to definition',
    ['gD'] = 'Go to declaration',
    ['<M-CR>'] = 'Code actions',
    ['<C-K>'] = 'Show diagnostics on the current line',
    ['[r'] = 'Go to previous reference',
    [']r'] = 'Go to next reference',
  } do
    local m = child.lua_get(([[
          (function()
            local m = vim.fn.maparg(%q, 'n', false, true)
            return { buffer = m.buffer, desc = m.desc }
          end)()
      ]]):format(lhs))
    eq({ lhs, m.buffer, m.desc }, { lhs, 1, want })
  end
  -- code_action is `mode = { 'n', 'x' }`; the visual half exists too
  eq(child.lua_get([[vim.fn.maparg('<M-CR>', 'x', false, true).buffer]]), 1)
  for _, lhs in ipairs { 'gr', 'ge', 'g0', 'gt', 'gH', 'gW', '<M-S-r>' } do
    -- no *buffer-local* mapping may exist; `maparg` legitimately resolves
    -- nothing for `gr` (a prefix now) and a global mapping is fine
    local buf = child.lua_get(([[vim.fn.maparg(%q, 'n', false, true).buffer or 0]]):format(lhs))
    eq({ lhs, buf }, { lhs, 0 })
  end
end

-- Regression for a bug this suite did NOT catch until a real TUI was driven:
-- the attach handlers were installed from nvim-lspconfig's `config`, but
-- nvim-lspconfig never loads for a Rust buffer (rust is not in servers.lua -
-- rustaceanvim owns it). Result: Rust buffers got no keymaps, no inlay hints
-- and no .vscode settings. Every other test here force-loads nvim-lspconfig
-- first and so could not see it. This one must not.
T['attach']['handlers work without nvim-lspconfig ever loading'] = function()
  start_fake('rust-analyzer', '{ inlayHintProvider = true }', nil, { no_lspconfig = true })

  eq(child.lua_get([[require('lazy.core.config').plugins['nvim-lspconfig']._.loaded ~= nil]]), false)
  eq(child.lua_get([[vim.fn.maparg('gd', 'n', false, true).buffer]]), 1)
  eq(child.lua_get([[vim.fn.maparg(' a', 'n', false, true).buffer]]), 1)
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), true)
end

-- `<leader>a` (rust-analyzer's grouped code actions) only ever worked because
-- the duplicate mason-started `rust_analyzer` client matched a filter written
-- with an underscore; rustaceanvim's own client is `rust-analyzer`. Deleting
-- the duplicate without fixing the filter would have removed the keymap and
-- nothing would have said so.
T['attach']['rustaceanvim keymap matches the hyphenated client name'] = function()
  start_fake('rust-analyzer')
  eq(child.lua_get([[vim.fn.maparg(' a', 'n', false, true).buffer]]), 1)
end

T['attach']['a differently named client does not get the rust keymap'] = function()
  start_fake('not-rust')
  eq(child.lua_get([[vim.tbl_isempty(vim.fn.maparg(' a', 'n', false, true))]]), true)
end

T['attach']['inlay hints and codelens are enabled per buffer'] = function()
  start_fake('faketest', '{ inlayHintProvider = true, codeLensProvider = { resolveProvider = false } }')
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), true)
  eq(child.lua_get([[vim.lsp.codelens.is_enabled({ bufnr = 0 })]]), true)
end

T['inlay hint toggle'] = new_set()

-- `<leader>uh` is the `Snacks.toggle` from `ucw.toggles` (Phase 8, D2), and
-- its get/set read and write the *global* flag. Attach used to write only the
-- buffer flag, leaving the global one at its `false` default, so the first
-- press "enabled" hints that were already on and it took two presses to turn
-- anything off (acceptance review P1). The fix is that the global flag *is*
-- the preference and attach mirrors it, so assert both halves.
--
-- `Snacks.toggle.get('inlay_hints')` is deliberate double duty: if
-- `ucw.toggles` ever stops claiming that id, `get()` falls back to *calling
-- the built-in factory*, whose get/set are `{ bufnr = 0 }` - and the
-- "buffer attached after the toggle" case below fails on exactly the
-- per-buffer-vs-global difference that P1 was.
T['inlay hint toggle']['the preference is on by default'] = function()
  start_fake('faketest', '{ inlayHintProvider = true }')
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled()]]), true)
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), true)
end

T['inlay hint toggle']['one press turns hints off, the next turns them back on'] = function()
  start_fake('faketest', '{ inlayHintProvider = true }')

  child.lua([[Snacks.toggle.get('inlay_hints'):toggle()]])
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), false)
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled()]]), false)

  child.lua([[Snacks.toggle.get('inlay_hints'):toggle()]])
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), true)
end

-- The second half of P1: turning them off has to survive opening the next file.
-- Attach fires again there, and a literal `true` would quietly undo the toggle.
T['inlay hint toggle']['a buffer attached after the toggle respects it'] = function()
  start_fake('faketest', '{ inlayHintProvider = true }')
  child.lua([[Snacks.toggle.get('inlay_hints'):toggle()]])

  -- same client, new buffer - i.e. what `:edit <another .lua>` does
  start_fake('faketest', '{ inlayHintProvider = true }')
  eq(child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]), false)
end

-- And the reason attach still writes the buffer flag rather than leaning on
-- inheritance: upstream's own LspDetach handler `_disable()`s the buffer when
-- the last inlay-capable client leaves, which *rawsets* `false` while the
-- global flag is true. Without the re-assert, a :LspRestart would leave hints
-- off in that buffer forever.
T['inlay hint toggle']['hints come back after a detach/reattach cycle'] = function()
  local id = start_fake('faketest', '{ inlayHintProvider = true }')
  child.lua(([[vim.lsp.buf_detach_client(0, %d)]]):format(id))
  -- Deliberately observed rather than asserted: whether detaching disables the
  -- buffer is upstream's business and upstream has changed its mind. On 0.12.4
  -- the LspDetach handler `_disable()`s it (`false` here), and on
  -- `NVIM v0.13.0-dev` it no longer does (`true`) - measured on both, with the
  -- nightly CI leg being what surfaced it. Asserting either value pins this
  -- config's test to a version of a decision it does not own.
  local disabled_on_detach = child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]) == false

  child.lua(([[vim.lsp.buf_attach_client(0, %d)]]):format(id))
  -- This is the line that is ours, and it holds either way. Note what it is
  -- worth depends on the observation above: where upstream does disable on
  -- detach, this passing is proof the re-assert in `ucw.lsp.attach` works;
  -- where it does not, the re-assert is simply not needed and this is weaker.
  -- Kept unconditional rather than skipped, because "hints are on after a
  -- reattach" is the behaviour, and a `MiniTest.skip()` is a green case.
  eq({ disabled_on_detach, child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]) }, {
    disabled_on_detach,
    true,
  })
end

T['vscode settings'] = new_set()

-- The half of `.vscode/settings.json` support that never worked: initial load.
-- It used to hang off lspconfig's `on_new_config`, which stopped firing; only
-- the live-reload watcher survived, so settings applied *only* if the file was
-- edited after the server was already up.
T['vscode settings']['are loaded and pushed when a client attaches'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "python.analysis.typeCheckingMode": "strict" }' },
                           dir .. '/.vscode/settings.json')
          return dir
        end)()
    ]])

  start_fake('faketest', '{}', root)

  eq(child.lua_get([[vim.lsp.get_client_by_id(1).settings.python.analysis.typeCheckingMode]]), 'strict')
  -- and the server was actually told about it
  eq(
    child.lua_get([[
            (function()
              for _, n in ipairs(_G.fake_notifications) do
                if n.method == 'workspace/didChangeConfiguration' then return true end
              end
              return false
            end)()
        ]]),
    true
  )
end

T['vscode settings']['single-file clients are left alone'] = function()
  start_fake('faketest')
  eq(
    child.lua_get([[
            (function()
              for _, n in ipairs(_G.fake_notifications) do
                if n.method == 'workspace/didChangeConfiguration' then return true end
              end
              return false
            end)()
        ]]),
    false
  )
end

-- The number of `didChangeConfiguration` notifications is part of the contract,
-- not an implementation detail: each one makes a pull-model server re-read its
-- config and re-check every open document, and the announce-and-re-apply design
-- this replaced sent up to four of them to open one file (measured - see
-- docs/design/phase3-settings-composition.md §1).
T['vscode settings']['each change is pushed exactly once'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "probe.value": 1 }' }, dir .. '/.vscode/settings.json')
          vim.g.__root = dir
          return dir
        end)()
    ]])

  local id = start_fake('faketest', '{}', root)
  local function pushes()
    return child.lua_get([[
            (function()
              local n = 0
              for _, note in ipairs(_G.fake_notifications) do
                if note.method == 'workspace/didChangeConfiguration' then n = n + 1 end
              end
              return n
            end)()
        ]])
  end
  eq(pushes(), 1)

  child.lua(([[
        vim.fn.writefile({ '{ "probe.value": 2 }' }, vim.g.__root .. '/.vscode/settings.json')
        _G.reloaded = vim.wait(10000, function()
          return vim.lsp.get_client_by_id(%d).settings.probe.value == 2
        end, 100)
    ]]):format(id))
  eq(child.lua_get([[_G.reloaded]]), true)
  eq(pushes(), 2)
end

-- One `.vscode` is one watch group, however many servers are rooted there. Each
-- client used to start its own pair of watchers on the same two paths and
-- announce its own reload, so a project with a few files open answered one
-- `_ltex.addToDictionary` with a stack of identical "Reloaded config" cards -
-- measured at four in a git repo holding one markdown, one lua, one json and
-- one toml buffer (marksman, lua_ls, taplo, jsonls; ltex itself is silent
-- because its command handler reloads it synchronously before any watcher
-- fires). The clients still reload individually - they compose over different
-- bases - but the event is the directory's, so the notification is too.
T['vscode settings']['one directory change is one notification'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "probe.value": 1 }' }, dir .. '/.vscode/settings.json')
          vim.g.__root = dir
          return dir
        end)()
    ]])

  local first = start_fake('faketest', '{}', root)
  -- In its own buffer, created off-screen: `:enew!` would abandon (and, unnamed
  -- and unmodified, wipe) the buffer the first client is on, which detaches it
  -- and takes the group with it - two servers in one project is the case here.
  local second = child.lua_get(([[
        (function()
          local buf = vim.api.nvim_create_buf(true, false)
          return vim.api.nvim_buf_call(buf, function()
            return vim.lsp.start({
              name = 'faketest_two',
              cmd = _G.new_fake_server({}),
              root_dir = %q,
            })
          end)
        end)()
    ]]):format(root))

  -- both read the same directory, so both are in the same group
  eq(child.lua_get(([[require('ucw.lsp.vscode').is_watching(%d)]]):format(first)), true)
  eq(child.lua_get(([[require('ucw.lsp.vscode').is_watching(%d)]]):format(second)), true)

  child.lua([[
        _G.reload_notices = {}
        vim.notify = function(msg)
          if type(msg) == 'string' and msg:match('^Reloaded config:') then
            table.insert(_G.reload_notices, msg)
          end
        end
    ]])

  child.lua(([[
        vim.fn.writefile({ '{ "probe.value": 2 }' }, vim.g.__root .. '/.vscode/settings.json')
        _G.reloaded = vim.wait(10000, function()
          return vim.lsp.get_client_by_id(%d).settings.probe.value == 2
            and vim.lsp.get_client_by_id(%d).settings.probe.value == 2
        end, 100)
        -- and give the second watcher of the group its full debounce window to
        -- prove it adds nothing, rather than asserting before it could have
        vim.wait(3000)
    ]]):format(first, second))
  eq(child.lua_get([[_G.reloaded]]), true)

  eq(child.lua_get([[#_G.reload_notices]]), 1)
  -- the message carries what the title used to: which servers were reloaded
  eq(child.lua_get([[_G.reload_notices[1]:match('faketest, faketest_two') ~= nil]]), true)
end

-- A workspace with nothing to say must say nothing. Before the push-when-changed
-- guard, attaching pushed unconditionally, so every client in every project got
-- woken up for a `.vscode/` that does not exist.
T['vscode settings']['a workspace with no .vscode is silent'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir, 'p')
          return dir
        end)()
    ]])
  start_fake('faketest', '{}', root)
  eq(
    child.lua_get([[
            (function()
              for _, n in ipairs(_G.fake_notifications) do
                if n.method == 'workspace/didChangeConfiguration' then return true end
              end
              return false
            end)()
        ]]),
    false
  )
  -- ...and looking for the settings must not have created the directory it
  -- looked in. `ltex_dict.get_settings_dir` used to `mkdir` on the *read*
  -- path, so every project that ever opened a prose file was left with an
  -- empty `.vscode/` in it (measured, design §1).
  eq(child.lua_get(([[vim.fn.isdirectory(%q)]]):format(root .. '/.vscode')), 0)
end

-- Creating a `.vscode/settings.json` in a project that is already open. The
-- watcher used to be started on the file itself, so `uv.fs_event_start` failed
-- silently whenever it did not exist yet and nothing was ever picked up until
-- the client restarted (second-round review, Q6). The root is watched for
-- `.vscode` appearing now, and the directory for changes inside it.
T['vscode settings']['a settings.json created after attach is picked up'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir, 'p')       -- deliberately no .vscode/
          vim.g.__root = dir
          return dir
        end)()
    ]])
  local id = start_fake('faketest', '{}', root)
  eq(child.lua_get(([[vim.lsp.get_client_by_id(%d).settings.probe]]):format(id)), vim.NIL)

  child.lua(([[
        vim.fn.mkdir(vim.g.__root .. '/.vscode', 'p')
        vim.fn.writefile({ '{ "probe.value": 7 }' }, vim.g.__root .. '/.vscode/settings.json')
        _G.picked_up = vim.wait(20000, function()
          local s = vim.lsp.get_client_by_id(%d).settings
          return s.probe ~= nil and s.probe.value == 7
        end, 200)
    ]]):format(id))
  eq(child.lua_get([[_G.picked_up]]), true)
end

-- The base snapshot exists so a key *removed* from settings.json goes away
-- instead of surviving in the accumulated settings forever. Nothing asserted
-- that before this rewrite, which made it the likeliest thing to lose.
T['vscode settings']['a key removed from settings.json disappears'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "probe.keep": 1, "probe.drop": 2 }' }, dir .. '/.vscode/settings.json')
          vim.g.__root = dir
          return dir
        end)()
    ]])

  local id = start_fake('faketest', '{}', root)
  eq(child.lua_get(([[vim.lsp.get_client_by_id(%d).settings.probe.drop]]):format(id)), 2)

  child.lua(([[
        vim.fn.writefile({ '{ "probe.keep": 1 }' }, vim.g.__root .. '/.vscode/settings.json')
        _G.reloaded = vim.wait(10000, function()
          return vim.lsp.get_client_by_id(%d).settings.probe.drop == nil
        end, 100)
    ]]):format(id))
  eq(child.lua_get([[_G.reloaded]]), true)
  eq(child.lua_get(([[vim.lsp.get_client_by_id(%d).settings.probe.keep]]):format(id)), 1)
end

-- `<dir>/<key>.<variant>.txt` is a `.vscode` setting, so it applies with no
-- `settings.json` present at all - which is what a vault built only by
-- `_ltex.addToDictionary` looks like. This used to be `ucw.lsp.ltex_dict`'s own
-- `LspAttach` handler; it is `ucw.lsp.vscode`'s SIDECAR_KEYS now.
T['vscode settings']['sidecar files apply without a settings.json'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ 'orloj', '', 'hradcany' }, dir .. '/.vscode/ltex.dictionary.en-US.txt')
          return dir
        end)()
    ]])
  local id = start_fake('faketest', '{}', root)
  -- blank lines are not words
  eq(
    child.lua_get(([==[vim.lsp.get_client_by_id(%d).settings.ltex.dictionary['en-US']]==]):format(id)),
    { 'orloj', 'hradcany' }
  )
end

-- Sidecars *union* with what settings.json declared for the same key. They
-- cannot be merged with `vim.tbl_deep_extend`, which replaces a nested list
-- wholesale (measured, design §2) - a naive layer would silently drop every
-- word declared inline.
T['vscode settings']['sidecar entries are unioned with declared ones'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "ltex.dictionary": { "en-US": ["declared"] } }' },
                           dir .. '/.vscode/settings.json')
          vim.fn.writefile({ 'orloj', 'declared' }, dir .. '/.vscode/ltex.dictionary.en-US.txt')
          return dir
        end)()
    ]])
  local id = start_fake('faketest', '{}', root)
  -- declared first, file entries appended, no duplicate
  eq(
    child.lua_get(([==[vim.lsp.get_client_by_id(%d).settings.ltex.dictionary['en-US']]==]):format(id)),
    { 'declared', 'orloj' }
  )
end

-- The P2 regression. It used to be a race between two writers of
-- `client.settings` patched up with a `User` autocmd; it holds structurally now,
-- because the dictionary file is one of the inputs `ucw.lsp.vscode` composes
-- rather than something written on top of its output afterwards.
T['vscode settings']['a reload keeps what the dictionary files added'] = function()
  load_lsp()
  child.lua(FAKE_SERVER)

  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ 'orloj' }, dir .. '/.vscode/ltex.dictionary.en-US.txt')
          vim.fn.writefile({ '{ "ltex.language": "en-US" }' }, dir .. '/.vscode/settings.json')
          vim.g.__root = dir
          return dir
        end)()
    ]])

  child.lua(([[
        vim.cmd('enew!')
        _G.cid = vim.lsp.start({
          name = 'ltex_plus',
          cmd = _G.new_fake_server({}),
          root_dir = %q,
        })
    ]]):format(root))

  -- both authors have had their say by the end of attach
  eq(child.lua_get([==[vim.lsp.get_client_by_id(_G.cid).settings.ltex.dictionary['en-US']]==]), { 'orloj' })
  eq(child.lua_get([[vim.lsp.get_client_by_id(_G.cid).settings.ltex.language]]), 'en-US')

  -- now edit the settings file, which is what the watcher reacts to, and wait
  -- for the change to land rather than for a fixed interval
  child.lua([[
        vim.fn.writefile({ '{ "ltex.language": "de-DE" }' }, vim.g.__root .. '/.vscode/settings.json')
        _G.reloaded = vim.wait(10000, function()
          return vim.lsp.get_client_by_id(_G.cid).settings.ltex.language == 'de-DE'
        end, 100)
    ]])
  eq(child.lua_get([[_G.reloaded]]), true)

  eq(child.lua_get([==[vim.lsp.get_client_by_id(_G.cid).settings.ltex.dictionary['en-US']]==]), { 'orloj' })
end

-- The watcher used to be torn down only if it happened to fire again after the
-- client had stopped, so a :LspRestart left a 2-second poll running for the
-- rest of the session (acceptance review P5).
T['vscode settings']['the watcher stops when the last buffer detaches'] = function()
  local root = child.lua_get([[
        (function()
          local dir = vim.fn.tempname()
          vim.fn.mkdir(dir .. '/.vscode', 'p')
          vim.fn.writefile({ '{ "a": 1 }' }, dir .. '/.vscode/settings.json')
          return dir
        end)()
    ]])
  local id = start_fake('faketest', '{}', root)
  eq(child.lua_get(([[require('ucw.lsp.vscode').is_watching(%d)]]):format(id)), true)

  -- LspDetach is per buffer and fires while the buffer is still attached, so
  -- a second buffer has to keep it alive. Created off-screen on purpose:
  -- `:enew` would abandon (and, unnamed and unmodified, wipe) the buffer the
  -- client is already on, which is the thing being kept alive here.
  local second = child.lua_get(([[
        (function()
          local buf = vim.api.nvim_create_buf(true, false)
          vim.lsp.buf_attach_client(buf, %d)
          return buf
        end)()
    ]]):format(id))
  child.lua(([[vim.lsp.buf_detach_client(%d, %d)]]):format(second, id))
  eq(child.lua_get(([[require('ucw.lsp.vscode').is_watching(%d)]]):format(id)), true)

  -- ...and detaching the last one has to stop it
  child.lua(([[
        for buf in pairs(vim.lsp.get_client_by_id(%d).attached_buffers) do
          vim.lsp.buf_detach_client(buf, %d)
        end
    ]]):format(id, id))
  eq(child.lua_get(([[require('ucw.lsp.vscode').is_watching(%d)]]):format(id)), false)
end

T['ltex'] = new_set()

-- ltex's `_ltex.addToDictionary` is the most-ported code in this phase: it moved
-- off lspconfig's `on_init` onto the native `commands` table, and its storage
-- helper reads the client's workspace folders to decide between the project
-- dictionary and the global one.
--
-- That helper was reading `client.config.workspace_folders`, which is always nil
-- on Neovim 0.12 (the folders live on the client, not the config it was built
-- from), so every word went to the global store no matter which project it was
-- added from. Nothing errored - the word *was* added, just in the wrong place,
-- which is invisible until you open the project on another machine.
T['ltex']['addToDictionary writes into the project, not the global store'] = function()
  load_lsp()
  child.lua(FAKE_SERVER)

  local dirs = child.lua_get([[
        (function()
          local root = vim.fn.tempname()
          vim.fn.mkdir(root, 'p')
          vim.g.__test_root = root
          vim.env.XDG_DATA_HOME = vim.fn.tempname()   -- keep the real global store out of it
          return { root = root, global = vim.fn.stdpath('data') .. '/ltex' }
        end)()
    ]])

  child.lua(([[
        vim.cmd('enew!')
        local id = vim.lsp.start({
          name = 'ltex_plus',
          cmd = _G.new_fake_server({}),
          root_dir = %q,
          commands = require('ucw.lsp.ltex_dict').commands,
        })
        local client = vim.lsp.get_client_by_id(id)
        client:exec_cmd({
          title = 'add',
          command = '_ltex.addToDictionary',
          arguments = { { uri = vim.uri_from_bufnr(0), words = { ['en-US'] = { 'orloj' } } } },
        }, { bufnr = 0 })
    ]]):format(dirs.root))

  eq(child.lua_get(([[vim.fn.readfile(%q)]]):format(dirs.root .. '/.vscode/ltex.dictionary.en-US.txt')), { 'orloj' })
  -- and the server was told to re-read its settings
  eq(
    child.lua_get([[
            (function()
              for _, n in ipairs(_G.fake_notifications) do
                if n.method == 'workspace/didChangeConfiguration' then return true end
              end
              return false
            end)()
        ]]),
    true
  )
end

T['hooks are gone'] = new_set()

-- Nothing should reintroduce the monkey-patch layer. `require('lspconfig')`
-- itself is now a deprecation warning upstream.
T['hooks are gone']['no ucw.lsp.hooks module and no lspconfig require'] = function()
  load_lsp()
  eq(child.lua_get([[pcall(require, 'ucw.lsp.hooks')]]), false)
  eq(child.lua_get([[pcall(require, 'ucw.lsp.lang.texlab')]]), false)
  eq(child.lua_get([[package.loaded['lspconfig'] ~= nil]]), false)
end

return T
