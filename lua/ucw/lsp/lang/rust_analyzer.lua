local utils = require('ucw.utils')
return function(opts)
  utils.prop_set(opts, 'settings.rust-analyzer.checkOnSave.command', 'clippy')
end
