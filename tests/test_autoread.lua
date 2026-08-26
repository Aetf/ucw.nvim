-- Coverage for reloading a file changed outside nvim (`ucw.extras`).
--
-- 'autoread' alone does nothing on its own schedule: it decides what happens
-- *when* nvim notices, and nvim only notices when something runs `:checktime`.
-- Core runs it on buffer entry and on terminal focus; `ucw.extras` adds the
-- idle case, which is the one a formatter or a `git checkout` hits while the
-- cursor sits still.
--
-- Two things here failed silently when this was first written and are the
-- reason the file exists. The notification fired for a file that was *deleted*
-- outside nvim, announcing a reload that had not happened and could not happen
-- (the buffer held the only copy). And the whole thing ran in the embedded
-- targets, where rewriting a buffer's text unasked is exactly what
-- `conform.lua`'s `format_on_save` refuses to do.

local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- Drive the check the way an idle editor does, then let the child settle: the
-- reload happens inside `:checktime`, so one RPC round-trip after it is
-- enough - no waiting on a timer.
local function externally_write(path, lines)
  child.lua(([[vim.fn.writefile(%s, %q)]]):format(vim.inspect(lines), path))
end

local function checktime()
  child.lua([[vim.cmd('checktime')]])
end

T['reload'] = new_set()

T['reload']['picks up a file rewritten outside nvim'] = function()
  local path = child.lua_get([[vim.fn.tempname()]])
  externally_write(path, { 'before' })
  child.lua(([[vim.cmd('edit %s')]]):format(path))
  eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), { 'before' })

  externally_write(path, { 'after' })
  checktime()
  eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), { 'after' })
end

T['reload']['leaves a modified buffer alone'] = function()
  -- The safety claim behind putting `:checktime` on a timer at all. Vim raises
  -- W12 and keeps the buffer; `nvim_input` is not involved, so the prompt does
  -- not block this test - the buffer contents are the assertion.
  local path = child.lua_get([[vim.fn.tempname()]])
  externally_write(path, { 'before' })
  child.lua(([[vim.cmd('edit %s')]]):format(path))
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'my unsaved edit' })]])

  externally_write(path, { 'theirs' })
  child.lua([[pcall(vim.cmd, 'checktime')]])
  eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), { 'my unsaved edit' })
  eq(child.lua_get([[vim.bo.modified]]), true)
end

T['notification'] = new_set()

-- `vim.notify` rather than the screen: what is under test is which of the two
-- FileChangedShellPost cases speaks, not how noice draws it.
local function capture_notifications()
  child.lua([[
        _G.ucw_test_notes = {}
        vim.notify = function(msg)
          table.insert(_G.ucw_test_notes, msg)
        end
    ]])
end

T['notification']['says so when a reload happened'] = function()
  local path = child.lua_get([[vim.fn.tempname()]])
  externally_write(path, { 'before' })
  child.lua(([[vim.cmd('edit %s')]]):format(path))
  capture_notifications()

  externally_write(path, { 'after' })
  checktime()
  eq(child.lua_get([[_G.ucw_test_notes]]), { 'Reloaded from disk (changed externally)' })
end

T['notification']['stays quiet when the file was deleted'] = function()
  -- The regression: `FileChangedShellPost` fires here too, with nothing
  -- reloaded and the buffer holding the only copy, so the reload message was
  -- a false statement printed next to nvim's true one (`E211`).
  local path = child.lua_get([[vim.fn.tempname()]])
  externally_write(path, { 'before' })
  child.lua(([[vim.cmd('edit %s')]]):format(path))
  capture_notifications()

  child.lua(([[vim.fn.delete(%q)]]):format(path))
  child.lua([[pcall(vim.cmd, 'checktime')]])
  eq(child.lua_get([[vim.v.fcs_reason]]), 'deleted')
  eq(child.lua_get([[_G.ucw_test_notes]]), {})
end

T['embedded contexts'] = new_set()

T['embedded contexts']['neither autocmd group exists under firenvim'] = function()
  -- Same technique as tests/test_fold.lua: boot only the module under test
  -- with the target marker set, before any test code runs.
  child.restart {}
  child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
  child.g.started_by_firenvim = true
  child.lua([[require('ucw.extras')]])

  eq(child.lua_get([[require('ucw.targets').is_full_ui()]]), false)
  for _, group in ipairs { 'AutoReadChanged', 'AutoReadNotify' } do
    -- `nvim_get_autocmds` raises on a group that was never created, which is
    -- the state being asserted - so "absent" is the error, not an empty list.
    eq({
      group,
      child.lua_get(([[
              (function()
                local ok, res = pcall(vim.api.nvim_get_autocmds, { group = %q })
                return ok and #res or 'absent'
              end)()]]):format(group)),
    }, { group, 'absent' })
  end
end

T['embedded contexts']['both exist in the full UI'] = function()
  -- The positive half: without it the case above passes just as well when the
  -- groups stop being created at all.
  for _, group in ipairs { 'AutoReadChanged', 'AutoReadNotify' } do
    eq({
      group,
      child.lua_get(([[#vim.api.nvim_get_autocmds({ group = %q }) > 0]]):format(group)),
    }, { group, true })
  end
end

return T
