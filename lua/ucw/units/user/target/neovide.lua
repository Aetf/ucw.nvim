local M = {}

M.description = 'Run in neovide'

M.activation = {
  wanted_by = {
    'target.gui'
  }
}

function M.config()
  vim.opt.guifont = 'Hack Nerd Font Mono:h13'
  vim.opt.mouse = 'nvi'
  vim.opt.mousemodel = 'popup'


  vim.g.neovide_remember_window_size = true
  -- this is in seconds, but this is slow, so disable it untile this it fixed
  vim.g.neovide_cursor_animation_length = 0
  vim.g.neovide_cursor_tail_length = 0.2
end

return M
