-- Neovide-specific settings. Not a plugin (no url) - just option/global
-- tweaks applied when running under a GUI frontend. Conditionally required
-- from ucw.init.boot() when ucw.targets.is_gui().
local M = {}

function M.setup()
  if vim.loop.os_uname().sysname == 'Darwin' then
    vim.opt.guifont = 'ComicCodeLigatures Nerd Font:h16'
  else
    vim.opt.guifont = 'ComicCodeLigatures Nerd Font Mono:h12'
  end

  vim.g.neovide_remember_window_size = true

  -- allow using meta key
  vim.g.neovide_input_use_logo = true

  -- cursors
  vim.g.neovide_cursor_antialiasing = false
  -- this is in seconds, but this is slow, so disable it until this is fixed
  vim.g.neovide_cursor_animation_length = 0
  vim.g.neovide_cursor_tail_length = 0.1
  vim.g.neovide_cursor_unfocused_outline_width = 0.125
end

return M
