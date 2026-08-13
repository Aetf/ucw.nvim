-- Coverage for the global keymap declarations in `ucw.plugins.which-key`.
--
-- Written after the Phase 3 acceptance review found `g[` / `g]` (previous /
-- next diagnostic) had not been mapped at all since Phase 1: the which-key v2
-- form was `{ rhs, "description" }`, and the v2 -> v3 conversion put the *rhs*
-- string into `desc` and left the entry with no rhs. which-key accepts that
-- without complaint - it just registers a label for a key nobody mapped - so
-- the popup still showed the entry, `maparg` returned nothing, and pressing
-- the key did nothing at all.
--
-- `ucw.lsp.actions` (tests/test_lsp_actions.lua) solves this for LSP entry
-- points by naming them as data. Everything else in which-key.lua is still
-- hand-written, so the guard here is the complementary one: whatever the spec
-- declares, a real mapping has to exist for it.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['diagnostic navigation'] = new_set()

-- The regression itself.
T['diagnostic navigation']['g[ and g] are really mapped'] = function()
  for _, lhs in ipairs { 'g[', 'g]' } do
    local map = child.lua_get(([[
            (function()
              local m = vim.fn.maparg(%q, 'n', false, true)
              return { has = not vim.tbl_isempty(m), callable = type(m.callback) == 'function', desc = m.desc }
            end)()
        ]]):format(lhs))
    eq({ lhs, map.has }, { lhs, true })
    eq({ lhs, map.callable }, { lhs, true })
    -- a description that still looks like a right-hand side is the exact
    -- shape of the original bug
    eq({ lhs, vim.startswith(map.desc or '', '<cmd>') }, { lhs, false })
  end
end

T['diagnostic navigation']['they jump to the next/previous diagnostic'] = function()
  child.lua([[
        vim.cmd('enew!')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three', 'four', 'five' })
        local ns = vim.api.nvim_create_namespace('ucw_test_diag')
        vim.diagnostic.set(ns, 0, {
          { lnum = 1, col = 0, message = 'first', severity = vim.diagnostic.severity.ERROR },
          { lnum = 3, col = 0, message = 'second', severity = vim.diagnostic.severity.ERROR },
        })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ]])

  local function line()
    -- `[==[` rather than `[[`: the `[1]` index would otherwise close the
    -- long string one bracket early
    return child.lua_get([==[vim.api.nvim_win_get_cursor(0)[1]]==])
  end

  -- `:normal` without `!` goes through mappings, so this exercises the real
  -- binding rather than calling ucw.keys.actions directly
  child.cmd('normal g]')
  eq(line(), 2)
  child.cmd('normal g]')
  eq(line(), 4)
  child.cmd('normal g[')
  eq(line(), 2)
end

T['which-key spec'] = new_set()

-- The general form of the same mistake, caught by its fingerprint: a `desc`
-- that is actually a right-hand side. In the v3 spec the rhs is the second
-- array element, so `{ lhs, desc = "<cmd>...<cr>" }` parses as a label with no
-- action - which is both a key that does nothing *and* a nonsense line in the
-- popup, so one check finds it either way.
--
-- Deliberately not "every labelled key must resolve to a mapping": which-key's
-- own presets document ~150 built-in keys (`zc`, `ap`, `<c-w>h`, ...) that
-- have no mapping by design, and they share `Config.mappings` with ours.
T['which-key spec']['no entry carries a right-hand side in its description'] = function()
  local bad = child.lua_get([[
        (function()
          local Config = require('which-key.config')
          local bad = {}
          for _, m in ipairs(Config.mappings or {}) do
            local desc = type(m.desc) == 'string' and m.desc or ''
            if desc:lower():match('^<cmd>') or desc:lower():match('^<plug>') or desc:match('^:%a') then
              table.insert(bad, ('%s %s -> %s'):format(m.mode, m.lhs, desc))
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(bad, {})
end

return T
