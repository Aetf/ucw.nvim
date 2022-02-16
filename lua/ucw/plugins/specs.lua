local pu = require('ucw.plugins.utils')
local M = {}

local function get_entry(name, fnname)
  return string.format([[require('ucw.config.%s').%s()]], name, fnname)
end

M.apply = function(packer)

end

return M
