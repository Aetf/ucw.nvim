return {
  'mizlan/iswap.nvim',
  cmd = { 'ISwapWith', 'ISwap' },
  config = function()
    require('iswap').setup {}
  end,
}
