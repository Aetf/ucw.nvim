return {
  'ggandor/lightspeed.nvim',
  lazy = false,
  dependencies = { 'tpope/vim-repeat' },
  config = function()
    -- use bidirection s
    vim.keymap.set('n', 's', '<Plug>Lightspeed_omni_s', { remap = true })
    vim.keymap.set('n', 'gs', '<Plug>Lightspeed_omni_gs', { remap = true })
  end,
}
