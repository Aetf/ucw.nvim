-- Coverage for global keymap *registration*, wherever it happens: since
-- Phase 8 (D1) that is three mechanisms - lazy.nvim `keys =` in each
-- plugin's spec (the bulk), `wk.add` in `ucw.plugins.which-key` (group
-- headers, core editor keys, the `<leader>l` tree), and `Snacks.toggle`
-- objects (`ucw.toggles` + `gitsigns.lua`) for the four toggles.
--
-- The founding bug: the Phase 3 acceptance review found `g[` / `g]`
-- (previous / next diagnostic) had not been mapped at all since Phase 1 -
-- the which-key v2 form was `{ rhs, "description" }`, and the v2 -> v3
-- conversion put the *rhs* string into `desc` and left the entry with no
-- rhs. which-key accepts that without complaint, so the popup showed the
-- entry while pressing the key did nothing. The same mistake is expressible
-- in a `keys =` entry (`Keys:_set` is `if keys.rhs then ...` - no rhs, no
-- mapping, label still shown), so the guards below scan the *real* mapping
-- tables, not any one mechanism's registry (Phase 8 acceptance review, R2).
--
-- `ucw.lsp.actions` (tests/test_lsp_actions.lua) solves this for LSP entry
-- points by naming them as data.

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
-- Phase 8 (D1) split registration across the plugin specs, and group headers
-- are the one part that deliberately stayed central and *eager* - a lazy
-- plugin's subtree with no header is exactly how octo was invisible until the
-- first `:Octo`. This is the boot-time census: every leader group this config
-- declares, present before any lazy plugin has loaded. `m.group` is `true` in
-- `Config.mappings` for header entries (measured; the display name lives in
-- `desc`).
T['which-key spec']['every leader group header is registered at boot'] = function()
  local groups = child.lua_get([[
        (function()
          local Config = require('which-key.config')
          local groups = {}
          for _, m in ipairs(Config.mappings or {}) do
            -- lhs is stored in spec notation, '<leader>T' literally (measured)
            if m.group and m.mode == 'n' and vim.startswith(m.lhs or '', '<leader>') then
              table.insert(groups, m.lhs)
            end
          end
          table.sort(groups)
          return groups
        end)()
    ]])
  eq(groups, {
    '<leader>b',
    '<leader>c',
    '<leader>f',
    '<leader>g',
    '<leader>go',
    '<leader>n',
    '<leader>q',
    '<leader>s',
    '<leader>t',
    '<leader>u',
    '<leader>w',
  })
end

T['lazy keys'] = new_set()

-- The other half of the octo fix: the keys themselves exist at boot as
-- lazy.nvim stubs - mapped and described while the plugin is still unloaded.
-- Before Phase 8 (D3), `maparg` on these was empty until the first `:Octo`.
T['lazy keys']['octo keys are live stubs before the plugin loads'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['octo.nvim']._.loaded ~= nil]]), false)
  for lhs, desc in pairs { [' goo'] = 'Pick an action', [' goi'] = 'Search issues', [' gop'] = 'Search issues' } do
    -- project out of the dict inside the child: the stub's `callback` is a
    -- function, which RPC cannot serialize whole
    local got = child.lua_get(([[vim.fn.maparg(%q, 'n', false, true).desc]]):format(lhs))
    eq({ lhs, got }, { lhs, desc })
  end
end

T['toggles'] = new_set()

-- The `Snacks.toggle`s (Phase 8 D2 mechanism, Phase 9 D4 placement: all
-- under `<leader>u`): each claimed id maps to a real key. The inlay-hint
-- toggle's *semantics* (global flag, not the built-in per-buffer factory)
-- are asserted where they can fail meaningfully, tests/test_lsp.lua's
-- 'inlay hint toggle' set; `<leader>uv`'s modes in
-- tests/test_diagnostics.lua. This is just the registration census.
T['toggles']['all seven toggles are registered and mapped'] = function()
  for id, lhs in pairs {
    inlay_hints = ' uh',
    diag_virtual_lines = ' uv',
    gitsigns_blame = ' ub',
    gitsigns_deleted = ' ud',
    diagnostics = ' uD',
    wrap = ' uw',
    spell = ' us',
  } do
    -- `rawget` of the registry, NOT `Snacks.toggle.get`: `get()` on an
    -- unclaimed id falls back to calling a built-in factory of that name,
    -- which for `inlay_hints` would *create* the per-buffer toggle and turn
    -- this into a test that can never fail.
    eq({ id, child.lua_get(([[require('snacks.toggle').toggles[%q] ~= nil]]):format(id)) }, { id, true })
    eq({ id, child.lua_get(([[vim.fn.maparg(%q, 'n') ~= '']]):format(lhs)) }, { id, true })
  end
end

-- The mechanism-independent form of the fingerprint scan below (Phase 8
-- acceptance review, R2): after D1 relocated most keys out of which-key's
-- registry, the registry-based case covers 31 entries where it used to cover
-- 85 - including octo's, which had been promised that coverage "for free".
-- This one reads the real mapping tables, so it sees `wk.add`, `keys =`,
-- `Snacks.toggle` and whatever mechanism comes next.
--
-- The colon classes are `^:%u` and `^:<`, not `^:%a`: Neovim's own default
-- mappings use command-shaped descs on purpose (`[b` -> ':bprevious',
-- `&` -> ':help &-default', ...) and cannot be filtered by script id - Lua
-- mappings all share the Lua sid. Measured: 33 false positives under
-- `^:%a`, zero under these, and every ex-command this config binds starts
-- uppercase (`:Gitsigns`, `:AutoSession`) or with `<C-U>`.
T['which-key spec']['no mapping anywhere carries a right-hand side in its description'] = function()
  local bad = child.lua_get([[
        (function()
          local bad = {}
          for _, mode in ipairs { 'n', 'v', 's', 'o', 'i', 'c', 't' } do
            for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
              local desc = m.desc or ''
              if
                desc:lower():match('^<cmd>')
                or desc:lower():match('^<plug>')
                or desc:match('^:%u')
                or desc:match('^:<')
              then
                table.insert(bad, ('%s %s -> %s'):format(mode, m.lhs, desc))
              end
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  eq(bad, {})
end

T['eager specs'] = new_set()

-- The trap Phase 8 itself discovered: `keys =` on a spec silently makes it
-- lazy, so five eager plugins carry an explicit `lazy = false` that nothing
-- else guards (acceptance review, R3). Measured before this case existed:
-- deleting bufferline's line left the suite 150/150 green while a real TUI
-- booted with no tabline; a lazy auto-session never arms session autosave.
-- gitsigns alone failed a test, and only because its toggles happen to
-- register in `config()`.
T['eager specs']['every keys-bearing eager plugin really loads at boot'] = function()
  for _, name in ipairs { 'gitsigns.nvim', 'bufferline.nvim', 'auto-session', 'Navigator.nvim', 'iron.nvim' } do
    eq(
      { name, child.lua_get(([[require('lazy.core.config').plugins[%q]._.loaded ~= nil]]):format(name)) },
      { name, true }
    )
  end
end

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
