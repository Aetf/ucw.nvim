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
end

return T
