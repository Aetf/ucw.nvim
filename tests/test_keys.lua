-- Coverage for global keymap *registration*, wherever it happens: since
-- Phase 8 (D1) that is three mechanisms - lazy.nvim `keys =` in each
-- plugin's spec (the bulk), `wk.add` in `ucw.plugins.which-key` (group
-- headers, core editor keys, the `<leader>l` tree), and `Snacks.toggle`
-- objects (`ucw.toggles` + `gitsigns.lua`) for the four toggles.
--
-- The founding bug: the Phase 3 acceptance review found `g[` / `g]` - the
-- config's own diagnostic pair at the time, retired in Phase 9.5 (T6) in
-- favour of Neovim's `[d`/`]d` - had not been mapped at all since Phase 1 -
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

-- The regression itself, on the keys that carry the feature now: Neovim's
-- own `[d`/`]d`/`[D`/`]D`. Asserting the defaults is not asserting upstream -
-- it is asserting that nothing in this config has shadowed them with an
-- entry of the broken shape, which is exactly how the feature was lost the
-- first time.
T['diagnostic navigation']['[d and ]d are really mapped'] = function()
  for _, lhs in ipairs { '[d', ']d', '[D', ']D' } do
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
  child.cmd('normal ]d')
  eq(line(), 2)
  child.cmd('normal ]d')
  eq(line(), 4)
  child.cmd('normal [d')
  eq(line(), 2)
end

-- The other half of T6: `g[`/`g]` are mini.ai's again (left/right edge of a
-- textobject, its upstream default keys), not a second diagnostic door.
T['diagnostic navigation']['g[ and g] belong to mini.ai, not diagnostics'] = function()
  for lhs, desc in pairs { ['g['] = 'Move to left "around"', ['g]'] = 'Move to right "around"' } do
    for _, mode in ipairs { 'n', 'x', 'o' } do
      local got = child.lua_get(([[vim.fn.maparg(%q, %q, false, true).desc]]):format(lhs, mode))
      eq({ lhs, mode, got }, { lhs, mode, desc })
    end
  end
end

T['cell navigation'] = new_set()

-- `[h`/`]h` (Phase 9.5, T6). Two things are asserted together because either
-- alone would have passed before this existed: that the keys jump, and that
-- they are *buffer-local to python*. The advance half of `<S-Enter>` used to
-- run `:normal ]h` against a mapping nothing had created since mini.ai's
-- `goto_*` keys were disabled, so it did nothing at all - a real file is
-- opened rather than assigning `vim.bo.filetype`, because an error out of an
-- ftplugin is swallowed on the option-assignment path.
T['cell navigation']['[h and ]h walk cells, in python buffers only'] = function()
  local path = vim.fn.tempname() .. '.py'
  vim.fn.writefile({ '# %%', 'a = 1', '# %%', 'b = 2', '# %%', 'c = 3' }, path)
  child.cmd('edit ' .. path)

  local function line()
    return child.lua_get([==[vim.api.nvim_win_get_cursor(0)[1]]==])
  end

  for _, lhs in ipairs { '[h', ']h' } do
    eq({ lhs, child.lua_get(([[vim.fn.maparg(%q, 'n', false, true).buffer]]):format(lhs)) }, { lhs, 1 })
  end

  child.lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  child.cmd('normal ]h')
  eq(line(), 3)
  child.cmd('normal ]h')
  eq(line(), 5)
  child.cmd('normal [h')
  eq(line(), 3)

  -- and nowhere else: no buffer-local mapping, and none leaked to the global
  -- table either (`maparg().buffer` is 0 for a global one, absent for none)
  child.cmd('enew!')
  for _, lhs in ipairs { '[h', ']h' } do
    eq({ lhs, child.lua_get(([[vim.fn.maparg(%q, 'n')]]):format(lhs)) }, { lhs, '' })
  end
  vim.fn.delete(path)
end

T['close with q'] = new_set()

-- The two windows that had no way out but `:q` (Phase 9.5, T7). Both halves
-- matter: that `q` is mapped there, and that it is *only* mapped there - a
-- global `q` would take macro recording away from every buffer.
T['close with q']['help and quickfix close on q, and nothing else does'] = function()
  for _, open in ipairs { 'help', 'copen' } do
    child.cmd(open)
    local m = child.lua_get([[
          (function()
            local m = vim.fn.maparg('q', 'n', false, true)
            return { buffer = m.buffer or 0, desc = m.desc, wins = #vim.api.nvim_tabpage_list_wins(0) }
          end)()
      ]])
    eq({ open, m.buffer, m.desc }, { open, 1, 'Close this window' })
    eq({ open, m.wins }, { open, 2 })

    child.cmd('normal q')
    eq({ open, child.lua_get([[#vim.api.nvim_tabpage_list_wins(0)]]) }, { open, 1 })
  end

  -- back in an ordinary buffer `q` is Neovim's own again (unmapped, so it
  -- records a macro)
  eq(child.lua_get([[vim.fn.maparg('q', 'n')]]), '')
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
    '<leader>q',
    '<leader>r',
    '<leader>s',
    '<leader>t',
    '<leader>u',
    '<leader>w',
  })
end

-- The two rules `ucw.plugins.which-key`'s header states for `<leader>`'s first
-- level, asserted rather than trusted, because both fail *silently* and only
-- in the popup: which-key renders a blank column for a missing icon, and a
-- stray `REPL` next to `find` reads as a typo, not as a bug. Neither shows up
-- in `maparg`, so no other test here can see them.
--
-- Only `wk.add` entries are visible in `Config.mappings` - a lazy `keys =`
-- entry never lands there - which is why `<leader>n`'s icon is registered in
-- which-key.lua as an entry with an icon and nothing else. That makes this
-- census exactly the first level: ten group headers plus the four leaves.
T['which-key spec']['every <leader> first-level entry follows the label/icon rules'] = function()
  local entries = child.lua_get([[
        (function()
          local Config = require('which-key.config')
          local seen = {}
          for _, m in ipairs(Config.mappings or {}) do
            -- exactly one key after the prefix. `<leader>go` is a subtree
            -- header one level down and rides on `<leader>g`'s icon.
            local rest = (m.lhs or ''):match('^<leader>(.*)$')
            if rest and vim.fn.strchars(rest) == 1 then
              local e = seen[m.lhs] or {}
              local icon = type(m.icon) == 'table' and m.icon.icon or m.icon
              e.icon = icon or e.icon
              e.desc = m.desc or e.desc
              e.group = e.group or (m.group and true or false)
              seen[m.lhs] = e
            end
          end
          local out = {}
          for lhs, e in pairs(seen) do
            local label = e.desc or ''
            local case = 'n/a'
            if e.group then
              -- rule 1: group labels are lowercase nouns
              case = label == label:lower() and 'lower' or 'MIXED'
            elseif label ~= '' then
              -- rule 1: leaf labels are Sentence-case verb phrases
              case = label:sub(1, 1):match('%u') and 'Sentence' or 'lower'
            end
            table.insert(out, table.concat({
              lhs,
              e.group and 'group' or 'leaf',
              (e.icon and e.icon ~= '') and 'icon' or 'NO-ICON',
              case,
            }, ' '))
          end
          table.sort(out)
          return out
        end)()
    ]])
  eq(entries, {
    '<leader>? leaf icon Sentence',
    '<leader>` leaf icon Sentence',
    '<leader>b group icon lower',
    '<leader>c group icon lower',
    '<leader>f group icon lower',
    '<leader>g group icon lower',
    '<leader>l leaf icon Sentence',
    '<leader>n leaf icon n/a',
    '<leader>q group icon lower',
    '<leader>r group icon lower',
    '<leader>s group icon lower',
    '<leader>t group icon lower',
    '<leader>u group icon lower',
    '<leader>w group icon lower',
  })
end

-- Visual mode used to render `c -> +2 keymaps`: `wk.add` defaults to mode `n`,
-- so the group *headers* were normal-mode only while their members were not.
-- Only the five headers with a visual-mode member are asserted - the others
-- are registered for `x` too but have nothing to head there, and which-key
-- does not draw an empty group.
T['which-key spec']['leader group headers exist in visual mode too'] = function()
  local groups = child.lua_get([[
        (function()
          local Config = require('which-key.config')
          local groups = {}
          for _, m in ipairs(Config.mappings or {}) do
            if m.group and m.mode == 'x' and vim.startswith(m.lhs or '', '<leader>') then
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
    '<leader>q',
    '<leader>r',
    '<leader>s',
    '<leader>t',
    '<leader>u',
    '<leader>w',
  })
end

-- `gq`/`gw` are labelled in which-key (the `operators` preset is off and has
-- no `gq` anyway) - labels *only*. If either ever acquires a right-hand side,
-- this config has silently taken over a built-in operator.
-- The complement to the fingerprint scan further down. That one catches a rhs
-- written *into* a desc; this catches the other way to get the same row, which
-- is what actually filled the visual-mode popup: a mapping with **no** desc at
-- all, for which which-key falls back to displaying the rhs (`Lightspeed_f`,
-- `MatchitVisualForward)`, `<Esc><Cmd>w<CR>`) or, for a Lua rhs, nothing.
--
-- Scoped to normal/visual/operator-pending, the three modes with a popup, and
-- to keys that popup can reach: `<Plug>` lhs are internal, and `<Snr>`/mouse
-- drags never render. A key counts as labelled if the *mapping* carries a
-- desc or `ucw.plugins.which-key` registers one for that mode - which is the
-- same union which-key itself displays.
T['which-key spec']['no key in a popup mode shows its rhs instead of a label'] = function()
  local unlabelled = child.lua_get([[
        (function()
          local Config = require('which-key.config')
          -- lhs as which-key stores it, per mode, for label-only entries
          local labelled = {}
          for _, m in ipairs(Config.mappings or {}) do
            if m.desc and m.desc ~= '' then
              labelled[(m.mode or 'n') .. ' ' .. vim.fn.keytrans(vim.keycode(m.lhs or ''))] = true
            end
          end
          local bad = {}
          for _, mode in ipairs { 'n', 'x', 'o' } do
            for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
              local lhs = vim.fn.keytrans(vim.keycode(m.lhs))
              local hidden = lhs:match('^<Plug>') or lhs:match('^<SNR>') or lhs:lower():match('mouse')
              local desc = m.desc or ''
              -- `:help x-default` is Neovim's own desc convention for its
              -- default mappings: fine in `:map`, a poor popup row, so those
              -- count as unlabelled too and get a real label or an exemption.
              if not hidden and (desc == '' or desc:match('^:help ')) and not labelled[mode .. ' ' .. lhs] then
                table.insert(bad, mode .. ' ' .. lhs)
              end
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
  -- What is left is Neovim's own normal-mode defaults, none of which reach
  -- the visual-mode popup this cleanup was about. Listed rather than filtered
  -- so that an unlabelled mapping of this config's own still fails here.
  --
  -- nvim-ufo's `zR`/`zM` are unlabelled too but absent from this list: ufo is
  -- `cond = is_full_ui` and the test child is headless, so they do not exist
  -- here. A headless census cannot speak for the full-UI-only plugins - the
  -- same limit `tests/test_fold.lua` works around by asserting the config
  -- rather than the live mapping.
  eq(unlabelled, {
    'n &',
    'n <BS>',
    'n <C-L>',
    'n <CR>',
    'n Y',
  })
end

T['which-key spec']['the reflow labels map nothing'] = function()
  for _, lhs in ipairs { 'gq', 'gw' } do
    for _, mode in ipairs { 'n', 'x', 'o' } do
      eq({ lhs, mode, child.lua_get(('vim.fn.maparg(%q, %q)'):format(lhs, mode)) }, { lhs, mode, '' })
    end
  end
end

T['lazy keys'] = new_set()

-- The other half of the octo fix: the keys themselves exist at boot as
-- lazy.nvim stubs - mapped and described while the plugin is still unloaded.
-- Before Phase 8 (D3), `maparg` on these was empty until the first `:Octo`.
T['lazy keys']['octo keys are live stubs before the plugin loads'] = function()
  eq(child.lua_get([[require('lazy.core.config').plugins['octo.nvim']._.loaded ~= nil]]), false)
  for lhs, desc in pairs { [' goo'] = 'Pick an action', [' goi'] = 'Search issues', [' gop'] = 'Search pull requests' } do
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

T['REPL keys'] = new_set()

-- Trial-period fix: on a machine without the REPL binary (measured: the
-- kpxc distrobox has no ipython) every REPL key threw E475 with a full
-- traceback, on every press. The guard in iron.lua probes the resolved
-- definition's binary first: one warning per filetype per session, then
-- silence - and no error ever reaches the user. Driven through the real
-- ` rr` mapping so the wrapper, not just the probe, is under test.
T['REPL keys']['degrade to a single warning when the binary is missing'] = function()
  local result = child.lua_get([[
        (function()
          require('iron.config').repl_definition.ucwtest = { command = { 'ucw-definitely-not-a-binary' } }
          vim.cmd('enew!')
          vim.bo.filetype = 'ucwtest'
          local warns = {}
          vim.notify = function(msg, level) table.insert(warns, { msg = msg, level = level }) end
          local cb = vim.fn.maparg(' rr', 'n', false, true).callback
          local ok1 = pcall(cb)
          local ok2 = pcall(cb)
          return { ok1 = ok1, ok2 = ok2, n = #warns, msg = warns[1] and warns[1].msg or '', level = warns[1] and warns[1].level }
        end)()
    ]])
  eq(result.ok1, true)
  eq(result.ok2, true)
  eq(result.n, 1)
  eq(result.msg:find('ucw%-definitely%-not%-a%-binary') ~= nil, true)
  eq(result.level, vim.log.levels.WARN)
end

-- The other failure shape: a filetype iron has no definition for at all.
-- iron's own resolution `error()`s there too (providers.lua:16/:29 - it has
-- no graceful path, by its own TODO comment), which is why the guard wraps
-- it in pcall rather than only probing the resolved binary.
T['REPL keys']['degrade the same way when no definition exists at all'] = function()
  local result = child.lua_get([[
        (function()
          vim.cmd('enew!')
          vim.bo.filetype = 'ucwnodef'
          local warns = {}
          vim.notify = function(msg) table.insert(warns, msg) end
          local cb = vim.fn.maparg(' rr', 'n', false, true).callback
          local ok1 = pcall(cb)
          local ok2 = pcall(cb)
          return { ok1 = ok1, ok2 = ok2, n = #warns, msg = warns[1] or '' }
        end)()
    ]])
  eq(result.ok1, true)
  eq(result.ok2, true)
  eq(result.n, 1)
  eq(result.msg:find('no usable REPL') ~= nil, true)
end

T['embedded contexts'] = new_set()

-- Phase 9 (D9): which-key is cond-gated off under vscode-neovim and stays
-- under firenvim. The assertion is the Phase 8 embedded-census pattern:
-- plugin load state plus a representative key from this file's `wk.add`
-- blocks (`<leader>ca`), because `cond = false` means neither `keys =` nor
-- `config()` ever ran - headless `wk.add` probing would be indistinguishable
-- from VeryLazy simply not firing (Phase 8 lesson).
T['embedded contexts']['which-key does not load under vscode-neovim'] = function()
  H.boot_embedded(child, 'vscode')
  -- a cond=false plugin is dropped from `Config.plugins` entirely (measured;
  -- indexing `._` on it is a nil error), so absence has two spellings
  local absent = child.lua_get([[
        (function()
          local p = require('lazy.core.config').plugins['which-key.nvim']
          return (p == nil or p._.loaded == nil) and package.loaded['which-key'] == nil
        end)()
    ]])
  eq(absent, true)
  eq(child.lua_get([[vim.fn.maparg(' ca', 'n')]]), '')
end

T['embedded contexts']['which-key loads under firenvim'] = function()
  H.boot_embedded(child, 'started_by_firenvim')
  eq(child.lua_get([[require('lazy.core.config').plugins['which-key.nvim']._.loaded ~= nil]]), true)
  eq(child.lua_get([[vim.fn.maparg(' ca', 'n') ~= '']]), true)
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
