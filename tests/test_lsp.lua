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
    for _, name in ipairs({ 'nvim-lspconfig', 'rustaceanvim', 'clangd_extensions.nvim', 'lsp-progress.nvim' }) do
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

T['attach'] = new_set()

local function start_fake(name, capabilities, root_dir, opts)
    if not (opts and opts.no_lspconfig) then
        load_lsp()
    end
    child.lua(FAKE_SERVER)
    return child.lua_get(
        ([[
        (function()
          vim.cmd('enew!')
          return vim.lsp.start({
            name = %q,
            cmd = _G.new_fake_server(%s),
            root_dir = %s,
          })
        end)()
    ]]):format(name, capabilities or '{}', root_dir and ('%q'):format(root_dir) or 'nil')
    )
end

-- The claim the whole "rustaceanvim is not a special case" argument rests on:
-- attach behaviour reaches a client that never went through `vim.lsp.enable()`.
T['attach']['handlers fire for a client started outside vim.lsp.enable'] = function()
    local id = start_fake('faketest')
    eq(id ~= vim.NIL and id ~= nil, true)

    local map = child.lua_get([[
        (function()
          local m = vim.fn.maparg('gd', 'n', false, true)
          return { buffer = m.buffer, rhs = m.rhs }
        end)()
    ]])
    eq(map.buffer, 1)
    eq(map.rhs, '<cmd>Telescope lsp_definitions<cr>')
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

    eq(
        child.lua_get([[vim.lsp.get_client_by_id(1).settings.python.analysis.typeCheckingMode]]),
        'strict'
    )
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

    eq(
        child.lua_get(([[vim.fn.readfile(%q)]]):format(dirs.root .. '/.vscode/ltex.dictionary.en-US.txt')),
        { 'orloj' }
    )
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
