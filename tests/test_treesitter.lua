-- Coverage for the one thing lua/ucw/plugins/treesitter.lua decides at boot:
-- whether to install parsers by itself.
--
-- Phase 6.5 made the project's own binaries resolvable through `PATH`
-- (docs/design/phase6.5-binary-deps.md §2.3), and the first thing that fell
-- out was a `tree-sitter` CLI becoming visible to the test children for the
-- first time. Every integration file promptly started downloading and
-- compiling a couple of dozen grammars into its scratch data directory. The
-- rule that stops it is the one Mason already applies to its own automatic
-- installs: nothing installs itself in a session with no UI attached.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['automatic parser install'] = new_set()

-- The precondition, asserted rather than assumed - exactly as
-- tests/test_lsp.lua does for Mason's equivalent. If a mini.test child ever
-- grew a UI, this whole file would silently start meaning something else.
T['automatic parser install']['the test child has no UI attached'] = function()
    eq(child.lua_get([[#vim.api.nvim_list_uis()]]), 0)
end

-- The gate itself. A fake `tree-sitter` is put on `PATH` *before* the config
-- boots, so the other half of the condition
-- (`executable('tree-sitter') == 1`) is true and the UI check is the only
-- thing left standing between this child and a parser build. Without it the
-- boot below emits `nvim-treesitter/install/...: Downloading ...` for the
-- whole `ensure_installed` list - which is how this was found, on a screenshot
-- assertion in tests/test_fold.lua that an install popup had covered up.
T['automatic parser install']['a UI-less boot installs nothing, even with a tree-sitter CLI reachable'] = function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    vim.fn.writefile({ '#!/bin/sh', 'echo 0.26.11' }, dir .. '/tree-sitter')
    vim.fn.setfperm(dir .. '/tree-sitter', 'rwxr-xr-x')

    local xdg = child.env.XDG_DATA_HOME
    child.restart({})
    child.env.XDG_DATA_HOME = xdg
    child.env.PATH = dir .. ':' .. child.env.PATH
    child.o.rtp = xdg .. ',' .. child.o.rtp
    child.o.packpath = xdg .. ',' .. child.o.packpath
    child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
    child.lua([[require('ucw').boot()]])
    child.lua([[require('lazy.manage').install()]])

    eq(child.lua_get([[vim.fn.executable('tree-sitter')]]), 1)
    eq(child.lua_get([[vim.fn.glob(vim.fn.stdpath('data') .. '/site/parser/*', false, true)]]), {})
    -- The warning is the other branch, and it must not fire either: a headless
    -- session is not missing anything, it simply was not asked.
    local messages = child.lua_get([[vim.api.nvim_exec2('messages', { output = true }).output]])
    eq(messages:find('nvim-treesitter', 1, true), nil)

    vim.fn.delete(dir, 'rf')
end

-- docs/design/phase6.5-acceptance-review.md R1. "No UI attached" turned out to
-- be the wrong half of the rule to borrow: firenvim and vscode-neovim both
-- attach a UI of their own - each calls `nvim_ui_attach` to get the redraw
-- events it renders into the browser textarea / VS Code editor - so
-- `#nvim_list_uis() > 0` is *true* in exactly the two contexts this config
-- otherwise keeps automatic installs out of.
--
-- Mason is protected there by two layers, and the gate above copied only the
-- inner one. `mason-tool-installer.lua` carries `cond = is_full_ui`, so under
-- an embedded target the plugin never loads at all; Mason's own "skip when no
-- UI is attached" rule - the half tests/test_lsp.lua asserts as a precondition
-- - only ever applies underneath that. nvim-treesitter has no `cond` to supply
-- the outer layer (it is `lazy = false, priority = 1000` for its highlighting,
-- which the embedded targets do want), so both halves have to be spelled out
-- in its `config()`.
--
-- Measured before the fix, in the shape below: a firenvim-marked session with
-- a `tree-sitter` CLI reachable ran the whole `ensure_installed` list - the
-- fake CLI was invoked 1.9 s after boot returned. Same class as
-- phase6-acceptance-review.md R1, about the same two hosts.
T['embedded contexts'] = new_set()

-- mini.test's own child never attaches a UI (the first case in this file
-- asserts exactly that), so "a UI is attached *and* the target is embedded"
-- cannot be staged inside it. This boots a second nvim over RPC and attaches
-- to it the same way firenvim and vscode-neovim do, rather than standing in
-- for that with a flag. It reuses the outer child's already-populated
-- XDG_DATA_HOME, so it costs a boot and not a plugin download.
--
-- What is observed is whether `require('nvim-treesitter').install` gets
-- *called*, recorded by wrapping the global `require` before `ucw.boot()`
-- runs. The wrapper returns the real module with `install` swapped for a
-- recorder that does not call through, which makes the whole case synchronous
-- and hermetic: `nvim_exec_lua` of `boot()` is a blocking request, and
-- treesitter's `config()` runs inside it (`lazy = false`), so by the time it
-- returns the gate has already been evaluated and the counter is final. The
-- first version of this test watched for the CLI being executed instead and
-- was a dud in both directions - the install is asynchronous, so it asserted
-- "nothing happened" a second or two before anything would have.
---@return integer install_calls
---@return integer n_uis  the precondition; a 0 here would make the result meaningless
local function boot_with_attached_ui(marker, xdg)
    -- Only needs to exist and be executable: `executable('tree-sitter') == 1`
    -- is the *inner* branch of the gate, and without it a session would take
    -- the warning path for reasons that have nothing to do with this test.
    -- It is never run, because the recorder does not call the real installer.
    local bin_dir = vim.fn.tempname()
    vim.fn.mkdir(bin_dir, 'p')
    vim.fn.writefile({ '#!/bin/sh', 'echo 0.26.11' }, bin_dir .. '/tree-sitter')
    vim.fn.setfperm(bin_dir .. '/tree-sitter', 'rwxr-xr-x')

    local saved_path, saved_xdg = vim.env.PATH, vim.env.XDG_DATA_HOME
    vim.env.PATH = bin_dir .. ':' .. vim.env.PATH
    vim.env.XDG_DATA_HOME = xdg

    local argv = {
        vim.v.progpath,
        '--embed',
        '--clean',
        '--cmd',
        [[lua _G.__install_calls = 0
          local real = require
          _G.require = function(name)
            local mod = real(name)
            if name == 'nvim-treesitter' and not _G.__patched then
              _G.__patched = true
              mod.install = function() _G.__install_calls = _G.__install_calls + 1 end
            end
            return mod
          end]],
        '--cmd',
        ('lua vim.o.rtp = %q .. "," .. %q .. "," .. vim.o.rtp'):format(xdg, vim.fn.getcwd()),
        '--cmd',
        ('lua vim.o.packpath = %q .. "," .. vim.o.packpath'):format(xdg),
    }
    -- Before `ucw.boot()`, for the same reason `H.boot_embedded` sets it
    -- there: lazy.nvim evaluates every spec's `cond` while the config is
    -- still being sourced, so there is nothing left to flip afterwards.
    if marker then
        vim.list_extend(argv, { '--cmd', ('lua vim.g.%s = true'):format(marker) })
    end

    local job = vim.fn.jobstart(argv, { rpc = true })
    vim.env.PATH, vim.env.XDG_DATA_HOME = saved_path, saved_xdg

    -- The UI goes on *before* the config boots, which is the order both hosts
    -- follow and the only order in which `config()` can see it.
    vim.rpcrequest(job, 'nvim_ui_attach', 80, 24, {})
    vim.rpcrequest(job, 'nvim_exec_lua', [[require('ucw').boot()]], {})

    local calls = vim.rpcrequest(job, 'nvim_exec_lua', 'return _G.__install_calls', {})
    local n_uis = vim.rpcrequest(job, 'nvim_exec_lua', 'return #vim.api.nvim_list_uis()', {})

    vim.fn.jobstop(job)
    vim.fn.delete(bin_dir, 'rf')

    return calls, n_uis
end

-- The positive control, and the reason the two cases below mean anything: the
-- same harness, the same attached UI, the same reachable CLI, differing only
-- in the target - and here the install *must* fire. Without it, a
-- `boot_with_attached_ui` that silently failed to boot at all would report
-- zero calls and pass every embedded case.
T['embedded contexts']['a UI-attached full-UI session does install'] = function()
    local calls, n_uis = boot_with_attached_ui(nil, child.env.XDG_DATA_HOME)
    eq(n_uis > 0, true)
    eq(calls, 1)
end

T['embedded contexts']['a UI-attached firenvim session installs nothing'] = function()
    local calls, n_uis = boot_with_attached_ui('started_by_firenvim', child.env.XDG_DATA_HOME)
    eq(n_uis > 0, true)
    eq(calls, 0)
end

T['embedded contexts']['a UI-attached vscode-neovim session installs nothing'] = function()
    local calls, n_uis = boot_with_attached_ui('vscode', child.env.XDG_DATA_HOME)
    eq(n_uis > 0, true)
    eq(calls, 0)
end

return T
