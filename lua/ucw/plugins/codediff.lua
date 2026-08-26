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
    -- The half codediff does not have (Phase 9.5, T7): a codediff tab shows
    -- the diff and never says which commit it is, let alone the message. The
    -- resolver is in `ucw.git` because the same key answers for a neogit
    -- buffer too, where the commit is the one under the cursor.
    {
      '<leader>gm',
      function()
        require('ucw.git').show_message()
      end,
      desc = 'Commit message for this diff',
      silent = true,
    },
  },
  config = function()
    require('codediff').setup {}
  end,
}
