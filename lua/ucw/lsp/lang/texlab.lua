local utils = require('ucw.utils')
local lu = require('ucw.lsp.utils')

return function(opts)
  opts.root_dir = lu.lazy_root_pattern('Makefile', '.latexmkrc', 'pages', 'figures')

  -- execute a forward search after a build
  utils.prop_set(opts, 'settings.texlab.build.forwardSearchAfter', true)
  -- build on save
  utils.prop_set(opts, 'settings.texlab.build.onSave', true)
  -- make sure preview mode is disabled
  utils.prop_set(opts, 'settings.texlab.build.args', {'-pv-', '-pvc-', '-pdf', '-interaction=nonstopmode', '-synctex=1', '%f'})
  -- use build subdir
  utils.prop_set(opts, 'settings.texlab.auxDirectory', 'build')

  -- chktex
  utils.prop_set(opts, 'settings.texlab.chktex.onOpenAndSave', true)
  utils.prop_set(opts, 'settings.texlab.chktex.onEdit', true)

  -- synctex with zathura
  utils.prop_set(opts, 'settings.texlab.forwardSearch.executable', 'zathura')
  utils.prop_set(opts, 'settings.texlab.forwardSearch.args', {
    '--synctex-editor-command',
    string.format('nvr --servername %s --remote-silent %%{input} +%%{line} -c "normal! zv"', vim.v.servername),
    -- synctex misses column info in output, because tex fundamentally doesn't store column info
    -- string.format('nvr --servername %s --remote-silent %%{input} +%%{line} -c "lua print([[%%{input} %%{line} %%{column}]])"', vim.v.servername),
    '--synctex-forward', '%l:1:%f', '%p'
  })
end