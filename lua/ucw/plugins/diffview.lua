return {
  -- sindrets/diffview.nvim has been unmaintained since 2024-06; switched to
  -- this actively maintained fork after a reproducible SIGSEGV in
  -- DiffviewFileHistory (coredump: recursive vim.wait() re-entering the
  -- libuv loop from lua/diffview/async.lua, corrupting LuaJIT's stack).
  -- Confirmed the crash still reproduces on this fork's HEAD too - the fork
  -- doesn't fix it, but it's the actively developed upstream to report it
  -- against and track for a future fix.
  'dlyongemallo/diffview-plus.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewLog' },
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. Same shape as
  -- neogit: already lazy on `cmd`, the key becomes an additional trigger.
  keys = {
    { '<leader>gh', '<cmd>DiffviewFileHistory<CR>', desc = 'History for current buffer', silent = true },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'echasnovski/mini.nvim',
  },
  config = function()
    require('diffview').setup {}
  end,
}
