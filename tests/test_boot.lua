local H = require('helpers')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T, child = H.new_integration_test()

-- The boot itself happens in the integration hook; what this asserts is that
-- it left no error behind where a user would see one.
T['smoke'] = function()
  eq(child.lua_get([[vim.v.errmsg]]), '')
  local messages = child.cmd_capture('messages')
  eq({ messages:find('E%d+:') ~= nil, messages:find('Error') ~= nil }, { false, false })
  eq(child.lua_get([[vim.tbl_count(require('lazy.core.config').plugins) > 0]]), true)
  -- A plugin whose `config()` threw is reported by lazy.nvim through
  -- `vim.notify` at ERROR level, which noice routes into the snacks history
  -- rather than `:messages`. Reverse-verified: a spec calling a nil helper in
  -- `config()` boots "clean" by every assertion above and fails here.
  local errors = child.lua_get([[
        (function()
          require('noice.message.router').update()
          local out = {}
          for _, n in ipairs(Snacks.notifier.get_history()) do
            if n.level == 'error' then table.insert(out, n.msg) end
          end
          return out
        end)()
    ]])
  eq(errors, {})
end

return T
