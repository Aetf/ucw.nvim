return {
  -- Replaces `sindrets/diffview.nvim` (unmaintained since 2024-06) and the
  -- `dlyongemallo/diffview-plus.nvim` fork. Both crash nvim on
  -- `:DiffviewFileHistory`: their hand-rolled async awaits with `vim.wait()`,
  -- which re-enters the libuv loop from inside a scheduled callback until
  -- LuaJIT's stack is corrupted. codediff drives git through `vim.system`
  -- callbacks instead, and its diff engine is a C port of VSCode's, so hunks
  -- carry character-level highlights on top of the line-level ones.
  --
  -- The C library is a prebuilt shared object fetched from GitHub releases on
  -- first use, so the first `:CodeDiff` in a fresh install needs network.
  'esmuellert/codediff.nvim',
  cmd = 'CodeDiff',
  -- Phase 8 (D1): the key lives with the spec rather than in `which-key.lua`.
  -- The plugin is already lazy on `cmd`, so this is an additional trigger.
  keys = {
    { '<leader>gh', '<cmd>CodeDiff history %<cr>', desc = 'History for current buffer', silent = true },
  },
  config = function()
    require('codediff').setup {}
  end,
}
