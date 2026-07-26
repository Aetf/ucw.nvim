local M = {}

M.url = 'lewis6991/gitsigns.nvim'
M.description = 'Git signs in gutter'

M.wants = {
  'plenary',
}
M.after = {
  'plenary',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('gitsigns').setup()
  -- define some functions as vim commands so they can be used with telescope
  local function cmd(name, fn)
    vim.api.nvim_create_user_command(name, fn, {})
  end
  cmd('GitsignsStageHunk', function() require('gitsigns').stage_hunk() end)
  cmd('GitsignsResetHunk', function() require('gitsigns').reset_hunk() end)
  cmd('GitsignsUndoStageHunk', function() require('gitsigns').undo_stage_hunk() end)
  cmd('GitsignsPreviewHunk', function() require('gitsigns').preview_hunk() end)

  cmd('GitsignsStageBuffer', function() require('gitsigns').stage_buffer() end)
  cmd('GitsignsResetBuffer', function() require('gitsigns').reset_buffer() end)
  cmd('GitsignsBlameLine', function() require('gitsigns').blame_line { full = true } end)
  cmd('GitsignsToggleCurrentLineBlame', function() require('gitsigns').toggle_current_line_blame() end)
  cmd('GitsignsDiffThis', function() require('gitsigns').diffthis() end)
  cmd('GitsignsDiff', function() require('gitsigns').diffthis('~') end)
  cmd('GitsignsToggleDeleted', function() require('gitsigns').toggle_deleted() end)
end

return M
