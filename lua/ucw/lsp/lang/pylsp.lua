local utils = require('ucw.utils')

return function(opts)
  local maxLineLength = 120
  local indentSize = 120
  utils.prop_set(opts, 'settings.pylsp.configurationSources', {'pycodestyle'})

  utils.prop_set(opts, 'settings.pylsp.plugins.pyflakes.enabled', true)
  utils.prop_set(opts, 'settings.pylsp.plugins.flake8.enabled', false)

  utils.prop_set(opts, 'settings.pylsp.plugins.mccabe.enabled', false)

  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.enabled', true)
  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.maxLineLength', maxLineLength)
  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.indentSize', indentSize)
  utils.prop_set(opts, 'settings.pylsp.plugins.pycodestyle.ignore', {
    'W391', -- why warn about empty line at the end of the file?
  })

  utils.prop_set(opts, 'settings.pylsp.plugins.pydocstyle.enabled', false)

  utils.prop_set(opts, 'settings.pylsp.plugins.yapf.enabled', false)
  utils.prop_set(opts, 'settings.pylsp.plugins.autopep8_format.enabled', false)
end
