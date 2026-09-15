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

-- Three kinds: `lsp` (a path under vim.lsp), `picker` (Phase 5) and `fn` (Phase 6).
-- Whether each `picker`/`fn` entry point is real cannot be checked here -
-- that needs the plugin loaded - so tests/test_picker.lua and
-- tests/test_format.lua carry those halves.
T['actions']['every action is exactly one of lsp/picker/fn, and describable'] = function()
  local bad = child.lua_get([[
        (function()
          local A = require('ucw.lsp.actions')
          local bad = {}
          for name, action in pairs(A.actions) do
            local kinds = 0
            for _, k in ipairs({ 'lsp', 'picker', 'fn' }) do
              if action[k] ~= nil then kinds = kinds + 1 end
            end
            if kinds ~= 1 then
              table.insert(bad, name .. ': needs exactly one of lsp/picker/fn, has ' .. kinds)
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

T['actions']['rhs() is a closure that names the action when it is broken'] = function()
  eq(child.lua_get([[type(require('ucw.lsp.actions').rhs('definitions'))]]), 'function')
  eq(child.lua_get([[pcall(require('ucw.lsp.actions').rhs, 'nope')]]), false)
  -- a broken entry point fails at press time with the action's name in the
  -- message, which is the whole point of naming entry points as data
  local res = child.lua_get([[
        (function()
          local A = require('ucw.lsp.actions')
          A.actions.ucw_probe = { desc = 'probe', lsp = 'buf.no_such_function' }
          local ok, err = pcall(A.rhs('ucw_probe'))
          A.actions.ucw_probe = nil
          return { ok = ok, err = tostring(err) }
        end)()
    ]])
  eq(res.ok, false)
  eq(res.err:find('ucw_probe', 1, true) ~= nil, true)
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

-- basedpyright and ruff both claim `python`; the `ft` trigger built from this
-- must list it once, or lazy.nvim registers the FileType trigger twice.
T['servers']['filetypes() lists a filetype claimed by two servers once'] = function()
  local n = 0
  for _, ft in ipairs(child.lua_get([[require('ucw.lsp').filetypes()]])) do
    if ft == 'python' then
      n = n + 1
    end
  end
  eq(n, 1)
end

return T
