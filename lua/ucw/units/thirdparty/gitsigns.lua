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
  -- XXX: waiting for neovim 0.7 release for nvim_add_user_command API
  vim.cmd [[command! GitsignsStageHunk <cmd>Gitsigns stage_hunk<cr>]]
  vim.cmd [[command! GitsignsResetHunk <cmd>Gitsigns reset_hunk<cr>]]
  vim.cmd [[command! GitsignsUndoStageHunk <cmd>lua require('gitsigns').undo_stage_hunk()<cr>]]
  vim.cmd [[command! GitsignsPreviewHunk <cmd>lua require('gitsigns').preview_hunk()<cr>]]

  vim.cmd [[command! GitsignsStageBuffer <cmd>lua require('gitsigns').stage_buffer()<cr>]]
  vim.cmd [[command! GitsignsResetBuffer <cmd>lua require('gitsigns').reset_buffer()<cr>]]
  vim.cmd [[command! GitsignsBlameLine <cmd>lua require('gitsigns').blame_line{full=true}<cr>]]
  vim.cmd [[command! GitsignsToggleCurrentLineBlame <cmd>lua require('gitsigns').toggle_current_line_blame()<cr>]]
  vim.cmd [[command! GitsignsDiffThis <cmd>lua require('gitsigns').diffthis()<cr>]]
  vim.cmd [[command! GitsignsDiff <cmd>lua require('gitsigns').diffthis('~')<cr>]]
  vim.cmd [[command! GitsignsToggleDeleted <cmd>lua require('gitsigns').toggle_deleted()<cr>]]
end

return M
