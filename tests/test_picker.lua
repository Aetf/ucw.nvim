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
