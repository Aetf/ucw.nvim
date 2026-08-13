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

return T
