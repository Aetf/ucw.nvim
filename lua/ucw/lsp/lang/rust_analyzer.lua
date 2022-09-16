local utils = require('ucw.utils')
local M = {}

function M.on_server_setup(opts)
  utils.prop_set(opts, 'settings.rust-analyzer.checkOnSave.command', 'clippy')
end

return M
