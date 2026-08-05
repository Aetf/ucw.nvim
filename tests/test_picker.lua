-- Coverage for the picker layer after Phase 5 moved it from Telescope to
-- snacks.picker.
--
-- Two different failure shapes are guarded here, and neither is "does the
-- picker work":
--
--   * A source name that no longer exists. `Snacks.picker` resolves unknown
--     names to `nil` rather than raising (`picker/config/init.lua`'s
--     `wrap(..., { check = true })`), so a source renamed upstream would turn
--     a key into a no-op - the same silent-dead-key shape as the Phase 3
--     acceptance review's P3, which went unnoticed for a month.
--   * A leftover reference to a plugin this phase deleted. Written generically
--     rather than as six separate greps, because the point is the class: the
--     config carried a dependency on `session-lens` for over a year after
--     upstream deprecated and archived it, and nothing said so.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['sources'] = new_set()

-- The other half of tests/test_lsp_actions.lua's "exactly one of
-- lsp/cmd/picker": that file can assert the shape without plugins, this one
-- asserts the names are real.
T['sources']['every ucw.lsp.actions picker entry is a real snacks source'] = function()
    local bad = child.lua_get([[
        (function()
          local picker = require('snacks.picker')
          local bad = {}
          for name, action in pairs(require('ucw.lsp.actions').actions) do
            if action.picker and type(picker[action.picker]) ~= 'function' then
              table.insert(bad, name .. ' -> snacks.picker.' .. action.picker)
            end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
    eq(bad, {})
end

-- Guard the guard: if `snacks.picker` ever stopped exposing sources as
-- callables, the test above would pass vacuously by finding nothing to check.
T['sources']['the check above is not vacuous'] = function()
    local counts = child.lua_get([[
        (function()
          local n = 0
          for _, action in pairs(require('ucw.lsp.actions').actions) do
            if action.picker then n = n + 1 end
          end
          return { n, type(require('snacks.picker').files), type(require('snacks.picker').no_such_source_at_all) }
        end)()
    ]])
    -- seven picker-backed LSP actions today; the point is only that it is not 0
    eq(counts[1] > 0, true)
    eq(counts[2], 'function')
    -- and that an unknown name really does come back as nil, which is what
    -- makes the assertion above meaningful rather than always-true
    eq(counts[3], 'nil')
end

T['sources']['the keys bound to pickers all resolve'] = function()
    -- Passed to `maparg` in `<>` notation, *not* run through
    -- `nvim_replace_termcodes` first: `<M-S-f>` termcodes to the byte sequence
    -- for `<M-F>`, which does not match how which-key registered it, so
    -- converting would fail this one key while every other key passed.
    -- `<leader>` is a literal space in this config.
    for _, lhs in ipairs({ '<C-p>', '<M-S-f>', '<M-f>', ' Th', ' bb', ' nn', ' nh', ' nd' }) do
        local map = child.lua_get(
            ([[
            (function()
              local m = vim.fn.maparg(%q, 'n', false, true)
              return { has = not vim.tbl_isempty(m), callable = type(m.callback) == 'function', desc = m.desc }
            end)()
        ]]):format(lhs)
        )
        eq({ lhs, map.has }, { lhs, true })
        eq({ lhs, map.callable }, { lhs, true })
    end
end

T['buffers picker'] = new_set()

-- The design doc called the buffers picker "the one with real behaviour
-- attached" and the acceptance review found both halves of that behaviour
-- missing anyway, because the only thing asserted was that the key opened *a*
-- picker. Both cases below assert on the picker's own resolved options rather
-- than on our config table, so a snacks-side rename fails here too.

-- R1: `preview = false` at source level is silently discarded - that field is a
-- previewer, not a switch, and the resolver is `opts.preview or <default>`. The
-- switch is `layout.preview`, which snacks rewrites into `layout.hidden`.
T['buffers picker']['has no preview window'] = function()
    local hidden = child.lua_get([[
        (function()
          local opts = require('snacks.picker.config').get({ source = 'buffers' })
          local layout = require('snacks.picker.config').layout(opts)
          return layout.hidden or {}
        end)()
    ]])
    eq(vim.tbl_contains(hidden, 'preview'), true)
end

-- R4: snacks ships three delete bindings for this source and the port replaced
-- one. `ucw.utils.bufdelete`'s jumplist preference is a deliberate choice, so a
-- key that quietly falls back to `Snacks.bufdelete` is the same silent
-- behaviour change as binding nothing at all.
T['buffers picker']['every delete key goes through ucw.utils.bufdelete'] = function()
    local bound = child.lua_get([[
        (function()
          local opts = require('snacks.picker.config').get({ source = 'buffers' })
          -- snacks normalises key names when it merges configs (`fix_keys`), so
          -- `<c-d>` is stored as `<C-D>`; look it up the same way it was written
          local function action(win, key)
            local spec = opts.win[win].keys[Snacks.util.normkey(key)]
            if type(spec) == 'string' then return spec end
            return type(spec) == 'table' and spec[1] or nil
          end
          return {
            ['input <c-d>'] = action('input', '<c-d>'),
            ['input <c-x>'] = action('input', '<c-x>'),
            ['list dd'] = action('list', 'dd'),
            has_action = type(opts.actions.ucw_bufdelete) == 'function',
          }
        end)()
    ]])
    eq(bound, {
        ['input <c-d>'] = 'ucw_bufdelete',
        ['input <c-x>'] = 'ucw_bufdelete',
        ['list dd'] = 'ucw_bufdelete',
        has_action = true,
    })
end

T['session hooks'] = new_set()

-- `close_aux_windows` had no coverage at all, which is how its rule could be
-- swapped for upstream's (Phase 5, W1) without anyone noticing that upstream's
-- also closes things ours never did. Driven through auto-session's own resolved
-- config rather than the spec file's local, so a hook dropped from
-- `pre_save_cmds` fails here too.
local function run_pre_save()
    child.lua([[
        for _, fn in ipairs(require('auto-session.config').pre_save_cmds) do fn() end
    ]])
end

-- R2: `filereadable` is false for a file you have not written yet, so borrowing
-- upstream's predicate wholesale closed that window on every *manual* save.
-- `mksession` records such a buffer fine, so the window held restorable state.
T['session hooks']['a not-yet-written file keeps its window'] = function()
    child.lua([[
        -- a second window so the "never close the last one" guard cannot be
        -- what saves this, and a real file in it so the sweep has a reason to run
        vim.cmd('edit ' .. vim.fn.getcwd() .. '/justfile')
        vim.cmd('split ' .. vim.fn.tempname() .. '-ucw-test-never-written.txt')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved work' })
        vim.g.ucw_test_newfile = vim.api.nvim_get_current_win()
    ]])
    eq(child.lua_get([[vim.api.nvim_win_is_valid(vim.g.ucw_test_newfile)]]), true)

    run_pre_save()

    eq(child.lua_get([[vim.api.nvim_win_is_valid(vim.g.ucw_test_newfile)]]), true)
end

-- The other side of the same predicate: the sweep still has to fire, or R2's
-- fix would be a licence to record neo-tree drawers into the session (W1).
T['session hooks']['a nofile drawer window does not'] = function()
    child.lua([[
        vim.cmd('edit ' .. vim.fn.getcwd() .. '/justfile')
        vim.cmd('vsplit')
        vim.cmd('enew')
        vim.bo.buftype = 'nofile'
        vim.bo.filetype = 'neo-tree'
        vim.g.ucw_test_drawer = vim.api.nvim_get_current_win()
    ]])
    run_pre_save()
    eq(child.lua_get([[vim.api.nvim_win_is_valid(vim.g.ucw_test_drawer)]]), false)
end

T['removed plugins'] = new_set()

-- Phase 5 deleted six plugins. lazy.nvim keeps a spec entry for anything still
-- referenced by a `dependencies` list, so a forgotten reference shows up here
-- rather than as a mysterious extra plugin in `:Lazy`.
T['removed plugins']['are not in the lazy spec any more'] = function()
    local present = child.lua_get([[
        (function()
          local plugins = require('lazy.core.config').plugins
          local gone = {
            'telescope.nvim', 'telescope-fzf-native.nvim', 'session-lens',
            'remote-nvim.nvim', 'nvim-notify', 'structlog.nvim',
          }
          local present = {}
          for _, name in ipairs(gone) do
            if plugins[name] then table.insert(present, name) end
          end
          table.sort(present)
          return present
        end)()
    ]])
    eq(present, {})
end

T['removed plugins']['their modules are not requirable either'] = function()
    -- A spec can be gone while a stale `require` survives in a config file - the
    -- runtime path would still be empty, so this fails loudly at the call site
    -- instead of the next time that code path happens to run.
    local loadable = child.lua_get([[
        (function()
          local bad = {}
          for _, mod in ipairs({ 'telescope', 'notify', 'structlog', 'session-lens', 'remote-nvim' }) do
            if pcall(require, mod) then table.insert(bad, mod) end
          end
          table.sort(bad)
          return bad
        end)()
    ]])
    eq(loadable, {})
end

T['notifications'] = new_set()

-- The chain is three deep and every link is silent when it breaks: `vim.notify`
-- is noice, noice renders through its `notify` view, and that view's backend is
-- pinned to snacks. If the backend were unavailable noice would quietly fall
-- back to its plain "mini" view rather than error, so assert the wiring itself.
T['notifications']['vim.notify routes through noice into the snacks notifier'] = function()
    eq(child.lua_get([[vim.notify == require('noice.source.notify').notify]]), true)
    eq(child.lua_get([[Snacks.config.notifier.enabled]]), true)
    eq(child.lua_get([[require('noice.config').options.views.notify.backend]]), 'snacks')
    eq(child.lua_get([[require('noice.view.backend.snacks').is_available ~= nil]]), true)
end

T['notifications']['notifications land in the notifier history'] = function()
    -- `vim.notify` only hands the message to noice's Manager; routing it to a
    -- view is done by `router._updater`, a throttled interval. Drive that
    -- directly rather than waiting for the timer - the update is what this
    -- asserts on, so calling it is the event, not a workaround for one.
    child.lua([[
        vim.notify('ucw phase5 probe', vim.log.levels.WARN, { title = 'test' })
        require('noice.message.router').update()
    ]])
    local found = child.lua_get([[
        (function()
          for _, notif in ipairs(Snacks.notifier.get_history()) do
            if notif.msg == 'ucw phase5 probe' then return true end
          end
          return false
        end)()
    ]])
    eq(found, true)
end

return T
