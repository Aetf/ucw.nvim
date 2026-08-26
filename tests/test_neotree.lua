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

T['fold emulation'] = new_set()

-- Focus the tree and wait for it, rather than for a duration: `Neotree` builds
-- the tree from an asynchronous directory scan, and this whole set exists
-- because of what that asynchrony did to the commands below.
local function open_tree()
  child.cmd('Neotree action=focus reveal=true')
  child.lua([[vim.wait(10000, function() return vim.bo.filetype == 'neo-tree' end, 20)]])
  eq(child.lua_get([[vim.bo.filetype]]), 'neo-tree')
end

local function lines()
  return child.lua_get([[vim.api.nvim_buf_line_count(0)]])
end

-- `zR`'s expansion finishes in a callback, and setting the depthlevel is the
-- last thing it does - so that is the condition to wait on. Cleared first so
-- this cannot pass on a value left by a previous press.
local function press_zR()
  child.lua([[vim.b.neotree_depthlevel = nil]])
  child.type_keys('zR')
  child.lua([[vim.wait(10000, function() return vim.b.neotree_depthlevel ~= nil end, 20)]])
end

-- The bug this guards: `recursive_open` opened a directory and immediately
-- asked for its children, but loading is asynchronous, so it saw none and
-- stopped one level short. `zR` therefore descended exactly one more level per
-- press instead of expanding everything - and the shape of that is precisely
-- "pressing it again does more", which is what is asserted here.
T['fold emulation']['zR expands everything in one press'] = function()
  open_tree()
  local collapsed = lines()

  press_zR()
  local expanded = lines()
  eq(expanded > collapsed, true)

  press_zR()
  eq(lines(), expanded)

  -- and the recorded depthlevel is the tree's real depth, not a number
  -- guessed before the expansion happened
  eq(child.lua_get([[vim.b.neotree_depthlevel]]) > 2, true)
end

-- `zm`/`zM` walk the same depthlevel back down. Asserted after `zR` because
-- that is the pairing that was broken: `zR` used to record a depth the tree
-- had not reached, so the first `zm` collapsed from the wrong number.
T['fold emulation']['zm steps back down from where zR left off'] = function()
  open_tree()
  press_zR()
  local expanded, top = lines(), child.lua_get([[vim.b.neotree_depthlevel]])

  child.type_keys('zm')
  eq(child.lua_get([[vim.b.neotree_depthlevel]]), top - 1)
  eq(lines() < expanded, true)

  child.type_keys('zM')
  eq(child.lua_get([[vim.b.neotree_depthlevel]]), 2)
  eq(lines() < expanded, true)
end

return T
