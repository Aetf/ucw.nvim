-- Regression coverage for diagnostic rendering after Phase 4.
--
-- Phase 4 deleted lsp_lines.nvim, which had *replaced* core's `virtual_lines`
-- handler with its own. Core renders the same thing now, so the plugin went and
-- two things it owned moved into config: the default, into `ucw.options`, and
-- the `<leader>uv` toggle, into `ucw.keys.actions`.
--
-- Both moves changed something that no assertion caught at the time: the plugin
-- was `cond = is_full_ui`, so the default has to stay off in firenvim/vscode,
-- and it was bound with `vim.keymap.set('', ...)`, so the toggle has to keep
-- its visual mode. The option name is the third trap - lsp_lines spelled it
-- `only_current_line`, and core silently ignores that, so a toggle that "did
-- not error" proved nothing.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

T['virtual_lines'] = new_set()

T['virtual_lines']['is on for the current line in the full UI'] = function()
  eq(child.lua_get([[vim.diagnostic.config().virtual_lines]]), { current_line = true })
end

T['virtual_lines']['is rendered by Neovim, not by a plugin'] = function()
  -- lsp_lines.setup() used to overwrite this handler; if anything ever does
  -- again, `current_line` stops meaning what ucw.options says it means.
  eq(
    child.lua_get([[
        (function()
          local info = debug.getinfo(vim.diagnostic.handlers.virtual_lines.show, 'S')
          return info.short_src:find('runtime/lua/vim/diagnostic%.lua') ~= nil
        end)()]]),
    true
  )
end

T['virtual_lines']['is off in the embedded contexts'] = function()
  -- Same technique as tests/test_fold.lua: the helper's `pre_case` boots the
  -- config before any test code runs, so the target is already decided by
  -- then. Boot only `ucw.options`, with the firenvim marker set.
  child.restart {}
  child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
  child.g.started_by_firenvim = true
  child.lua([[require('ucw.options')]])

  eq(child.lua_get([[require('ucw.targets').is_full_ui()]]), false)
  -- A browser textarea cannot spare two or three lines under the cursor.
  -- lsp_lines was `cond = is_full_ui`; this is where that condition went.
  eq(child.lua_get([[vim.diagnostic.config().virtual_lines]]), false)
end

T['<leader>uv'] = new_set()

T['<leader>uv']['toggles the rendering off and back on'] = function()
  child.lua([[Snacks.toggle.get('diag_virtual_lines'):toggle()]])
  eq(child.lua_get([[vim.diagnostic.config().virtual_lines]]), false)

  child.lua([[Snacks.toggle.get('diag_virtual_lines'):toggle()]])
  -- Spelled `current_line`, not lsp_lines' `only_current_line`, which core
  -- accepts and ignores.
  eq(child.lua_get([[vim.diagnostic.config().virtual_lines]]), { current_line = true })
end

T['<leader>uv']['is bound in normal and visual mode'] = function()
  -- lsp_lines bound it with mode '' (normal + visual/select + operator
  -- pending); which-key defaults to normal only, which silently dropped the
  -- others when the binding moved.
  eq(child.lua_get([[vim.fn.maparg(' uv', 'n') ~= '']]), true)
  eq(child.lua_get([[vim.fn.maparg(' uv', 'v') ~= '']]), true)
end

return T
