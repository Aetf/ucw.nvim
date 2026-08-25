-- Neo-tree is `lazy = false` and its event wiring is set up lazily, when a
-- source first subscribes - i.e. when the tree is first opened, not at boot.
-- That distinction is the whole reason this file exists rather than a case in
-- tests/test_boot.lua: asserting "booting produced no error notification"
-- measured red, green, red across three identical runs on the same Neovim,
-- because whether the subscribe happens during boot is a race. Opening the tree
-- is deterministic - 3/3 either way on both 0.12.4 and 0.13-dev.
--
-- What it protects: an error here is delivered as a notification, notifications
-- are floats, and a float lands on whatever is on screen - so before this case
-- existed the only thing that noticed was `tests/test_tui_screenshot.lua` going
-- intermittently red because the float covered the buffer text it was reading.
-- Those screen-reading cases now dismiss notifications and point here.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['neo-tree'] = new_set()

-- Level rather than text, so the next breakage is caught too. This is the case
-- that found the 0.13 incompatibility and the one that closed it: on
-- `NVIM v0.13.0-dev` it failed with `E216: No such group or event:
-- BufModifiedSet`, an event Neovim removed (|OptionSet| with pattern
-- `modified` replaces it) and that neo-tree kept registering unconditionally
-- on the `v2.x` branch this config used to pin. `v3.x` picks between the two
-- at runtime, so the assertion holds on both Neovims now - see
-- docs/design/phase9.5-trial-period.md §11, which supersedes phase7-ci.md
-- §9.8's "moving off v2.x is a plugin decision".
T['neo-tree']['opening the tree raises no error notification'] = function()
  child.lua([[pcall(function() vim.cmd('Neotree show') end)]])

  eq(
    child.lua_get([[
      (function()
        local out = {}
        local ok, history = pcall(function() return Snacks.notifier.get_history() end)
        if not ok then
          return { 'could not read the notifier history: ' .. tostring(history) }
        end
        for _, n in ipairs(history) do
          if n.level == 'error' or n.level == vim.log.levels.ERROR then
            table.insert(out, tostring(n.msg))
          end
        end
        return out
      end)()
    ]]),
    {}
  )
end

return T
