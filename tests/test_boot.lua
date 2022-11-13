local H = require('helpers')
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T, child = H.new_integration_test()

T['smoke'] = function()
    -- smoke test that nvim boots without error with current config
end

return T
