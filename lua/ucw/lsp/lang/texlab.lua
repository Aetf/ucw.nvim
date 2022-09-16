local utils = require('ucw.utils')
local lu = require('ucw.lsp.utils')

local M = {}

-- a global function accepting backward search request
---@param line number line info
---@param col number column info
function texlab_backward_search(filename, line, col)
  -- open file
  vim.cmd([[drop ]] .. filename)

  -- move to requested line
  local l, c = unpack(vim.api.nvim_win_get_cursor(0))
  if not line or line < 1 then
    line = l
  end
  if not col or col < 0 then
    col = c
  end
  vim.api.nvim_win_set_cursor(0, {line, col})

  -- unfold cursor line
  vim.cmd [[normal! zv]]
  -- move to center
  vim.cmd [[normal! zz]]

  -- return empty string to silent when called by --remote-expr
  return ""
end

function M.on_server_setup(opts)
  opts.root_dir = lu.lazy_root_pattern('.latexmkrc', 'Makefile')

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
    string.format([[nvim --server %s --remote-expr 'v:lua.texlab_backward_search("%%{input}", %%{line}, %%{column})']], vim.v.servername),
    '--synctex-forward', '%l:1:%f', '%p'
  })
end

function M.on_new_config(new_config, root_dir)
  -- texlab uses a temp dir to run chktex, only only copies 'chktexrc' to it,
  -- but chktex on linux uses '.chktexrc'.
  -- before that is fixed, use env var to force a chtexrc location
  -- see https://github.com/latex-lsp/texlab/issues/309#issuecomment-955767508
  local cmd_env = utils.prop_get_table(new_config, 'cmd_env')
  cmd_env['CHKTEXRC'] = root_dir

  -- texlab needs texlab.rootDirectory to be set to correctly detect multi-folder structures.
  -- note that this is different from lsp.client's root_dir and workspace_folders.
  -- see https://github.com/latex-lsp/texlab/issues/571
  utils.prop_set(new_config, 'settings.texlab.rootDirectory', root_dir)
end

return M
