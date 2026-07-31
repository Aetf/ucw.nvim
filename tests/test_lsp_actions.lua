-- Unit coverage for the two plain-data tables the LSP subsystem is built on:
-- `ucw.lsp.actions` and `ucw.lsp.servers`. No plugins needed, so these run in
-- `just unit` and fail fast.
--
-- Why this file exists at all: everything here used to be spelled out inline in
-- two different places, and it rotted silently across Neovim releases.
-- `vim.lsp.buf.range_code_action` was removed in 0.10 and `vim.lsp.declaration`
-- never existed, yet both stayed bound to keys for years - a keymap whose rhs
-- is `nil` simply does nothing, and a `<cmd>lua …<cr>` string is not checked
-- until it is pressed. Naming the entry points as data makes that testable.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_unit_test()

T['actions'] = new_set()

-- The regression that motivated the whole table.
T['actions']['every vim.lsp entry point still exists'] = function()
    local broken = child.lua_get([[
        (function()
          local A = require('ucw.lsp.actions')
          local bad = {}
          for name, action in pairs(A.actions) do
            if action.lsp and type(A.resolve(action.lsp)) ~= 'function' then
              table.insert(bad, name .. ' -> vim.lsp.' .. action.lsp)
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
    eq(broken, {})
end

T['actions']['every action is exactly one of lsp/cmd, and describable'] = function()
    local bad = child.lua_get([[
        (function()
          local A = require('ucw.lsp.actions')
          local bad = {}
          for name, action in pairs(A.actions) do
            if (action.lsp ~= nil) == (action.cmd ~= nil) then
              table.insert(bad, name .. ': needs exactly one of lsp/cmd')
            end
            if type(action.desc) ~= 'string' or action.desc == '' then
              table.insert(bad, name .. ': missing desc')
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
    eq(bad, {})
end

-- `resolve` walking a missing path must return nil rather than throw, or the
-- test above would blow up instead of reporting which action is broken.
T['actions']['resolve tolerates missing paths'] = function()
    eq(child.lua_get([[require('ucw.lsp.actions').resolve('buf.no_such_function') == nil]]), true)
    eq(child.lua_get([[require('ucw.lsp.actions').resolve('no.such.path.at.all') == nil]]), true)
end

T['actions']['wk() builds a which-key v3 entry and rejects typos'] = function()
    -- queried field by field: a which-key entry mixes an array part (lhs, rhs)
    -- with a hash part, which the RPC bridge to the child cannot marshal whole
    local function field(expr)
        return child.lua_get(
            ([[(function() local e = require('ucw.lsp.actions').wk('<leader>ld', 'definitions', { buffer = 7 }) return %s end)()]]):format(
                expr
            )
        )
    end
    eq(field('e[1]'), '<leader>ld')
    eq(field('e[2]'), '<cmd>Telescope lsp_definitions<cr>')
    eq(field('e.desc'), 'Go to definition')
    eq(field('e.buffer'), 7)

    -- code_action is n+x; the mode has to survive into the spec or visual-mode
    -- code actions silently stop working (this is what replaced the removed
    -- range_code_action binding)
    eq(child.lua_get([[require('ucw.lsp.actions').wk('<leader>la', 'code_action').mode]]), { 'n', 'x' })

    eq(child.lua_get([[pcall(require('ucw.lsp.actions').wk, 'x', 'nope')]]), false)
end

T['servers'] = new_set()

T['servers']['each entry is a non-empty list of filetype strings'] = function()
    local bad = child.lua_get([[
        (function()
          local bad = {}
          for name, fts in pairs(require('ucw.lsp.servers')) do
            if type(fts) ~= 'table' or #fts == 0 then
              table.insert(bad, name .. ': not a non-empty list')
            else
              for _, ft in ipairs(fts) do
                if type(ft) ~= 'string' then table.insert(bad, name .. ': non-string filetype') end
              end
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
    eq(bad, {})
end

-- The duplicate-client bug in one assertion: rustaceanvim owns rust-analyzer,
-- so enabling it here too is what attached two clients to every Rust buffer and
-- rendered every inlay hint twice.
T['servers']['rust is left to rustaceanvim'] = function()
    eq(child.lua_get([[require('ucw.lsp.servers').rust_analyzer == nil]]), true)
    eq(child.lua_get([[vim.tbl_contains(require('ucw.lsp').server_names(), 'rust_analyzer')]]), false)
end

T['servers']['filetypes() is the sorted, deduplicated union'] = function()
    -- basedpyright and ruff both claim `python`; it must appear once
    local fts = child.lua_get([[require('ucw.lsp').filetypes()]])
    local seen = {}
    for _, ft in ipairs(fts) do
        eq({ ft, seen[ft] }, { ft, nil })
        seen[ft] = true
    end
    eq(seen['python'] ~= nil, true)
    eq(seen['lua'] ~= nil, true)

    local sorted = vim.deepcopy(fts)
    table.sort(sorted)
    eq(fts, sorted)
end

T['servers']['server_names() is sorted and matches the table'] = function()
    local names = child.lua_get([[require('ucw.lsp').server_names()]])
    local sorted = vim.deepcopy(names)
    table.sort(sorted)
    eq(names, sorted)
    eq(#names, child.lua_get([[vim.tbl_count(require('ucw.lsp.servers'))]]))
end

return T
