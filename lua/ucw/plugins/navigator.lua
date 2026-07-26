return {
  'Aetf/Navigator.nvim',
  lazy = false,
  config = function()
    require('Navigator').setup {
      auto_save = 'all',
      disable_on_zoom = true,
    }
  end,
}
