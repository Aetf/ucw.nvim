return {
  'Aetf/Navigator.nvim',
  lazy = false,
  config = function()
    -- `mux` is annotated required but is optional in practice: Navigator picks
    -- the multiplexer itself when it is not given (that is the whole point of
    -- its auto-detection), which is what this config wants.
    ---@diagnostic disable-next-line: missing-fields
    require('Navigator').setup {
      auto_save = 'all',
      disable_on_zoom = true,
    }
  end,
}
