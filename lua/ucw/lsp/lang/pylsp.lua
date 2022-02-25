local utils = require('ucw.utils')

return function(opts)
  local maxLineLength = 120
  local indentSize = 120
  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.maxLineLength', maxLineLength)
  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.indentSize', indentSize)
end
