local M = {}

M.description = 'Run in neovide'

M.activation = {
  wanted_by = {
    'target.gui'
  }
}

function M.config()
  -- vim.opt.guifont = 'Comic Code Ligatures:h12'
  if vim.fn.has('macunix') then
    vim.opt.guifont = 'ComicCodeLigatures Nerd Font:h16'
  else
    vim.opt.guifont = 'ComicCodeLigatures Nerd Font Mono:h12'
  end

  vim.g.neovide_remember_window_size = true

  -- inputs

  -- allow using meta key
  vim.g.neovide_input_use_logo = true

  -- cursors
  vim.g.neovide_cursor_antialiasing = false
  -- this is in seconds, but this is slow, so disable it untile this it fixed
  -- vim.g.neovide_cursor_animation_length = 0.1
  vim.g.neovide_cursor_animation_length = 0
  vim.g.neovide_cursor_tail_length = 0.1
  vim.g.neovide_cursor_unfocused_outline_width=0.125
  -- vim.g.neovide_cursor_vfx_mode = 'pixiedust'
end

return M
