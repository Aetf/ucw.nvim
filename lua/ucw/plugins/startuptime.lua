return {
  'dstein64/vim-startuptime',
  cmd = 'StartupTime',
  config = function()
    vim.g.startuptime_exe_args = { '.' }
    vim.g.startuptime_tries = 5
  end,
}
