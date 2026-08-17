return {
  'hkupty/iron.nvim',
  -- `keys` alone would flip the spec to lazy-loading; iron owns REPL windows
  -- from startup, so stay eager (Phase 8 relocates registration, not
  -- triggers).
  lazy = false,
  -- `<leader>r` = REPL (Phase 9, D5; the tree lived on `<leader>e`, freed
  -- for the explorer). These are bound here rather than through iron's
  -- `keymaps =` table: iron hardcodes identifier-style descs
  -- (`iron_repl_send_file`, core.lua:832) with no way to override, and every
  -- rhs in its `named_maps` is a thin wrapper over the public API anyway -
  -- so the spec binds the same entry points with prose descriptions (Phase 8
  -- handoff R5b). `rs` is mode-symmetric on purpose: motion in normal,
  -- selection in visual - one key, one meaning.
  keys = {
    -- there was no "open the REPL" key at all before Phase 9
    { '<leader>rr', '<cmd>IronRepl<cr>', desc = 'Toggle the REPL window', silent = true },
    {
      '<leader>rs',
      function()
        require('iron.core').run_motion('send_motion')
      end,
      desc = 'Send a motion to the REPL',
      silent = true,
    },
    {
      '<leader>rs',
      function()
        require('iron.core').visual_send()
      end,
      desc = 'Send the selection to the REPL',
      mode = 'v',
      silent = true,
    },
    {
      '<leader>rl',
      function()
        require('iron.core').send_line()
      end,
      desc = 'Send the current line to the REPL',
      silent = true,
    },
    {
      '<leader>rf',
      function()
        require('iron.core').send_file()
      end,
      desc = 'Send the whole file to the REPL',
      silent = true,
    },
    {
      '<leader>r<CR>',
      function()
        require('iron.core').send(nil, string.char(13))
      end,
      desc = 'Send a return to the REPL',
      silent = true,
    },
    {
      '<leader>rc',
      function()
        require('iron.core').send(nil, string.char(3))
      end,
      desc = 'Interrupt the REPL',
      silent = true,
    },
    {
      '<leader>rx',
      function()
        require('iron.core').send(nil, string.char(12))
      end,
      desc = 'Clear the REPL screen',
      silent = true,
    },
    {
      '<leader>rq',
      function()
        require('iron.core').close_repl()
      end,
      desc = 'Exit the REPL',
      silent = true,
    },
    {
      '<C-Enter>',
      "<cmd>lua require('ucw.keys.actions').iron_send_block()<cr>",
      desc = 'Send block to REPL',
      mode = { 'n', 'v', 'i' },
      silent = true,
    },
    {
      '<S-Enter>',
      "<cmd>lua require('ucw.keys.actions').iron_send_block({next=true})<cr>",
      desc = 'Send block to REPL and move to next',
      mode = { 'n', 'v', 'i' },
      silent = true,
    },
  },
  init = function()
    -- we define our own mapping
    vim.g.iron_map_defaults = 0
    vim.g.iron_map_extended = 0
  end,
  config = function()
    local iron = require('iron.core')

    iron.setup {
      config = {
        scratch_repl = false,
        highlight_last = false,
        should_map_plug = false,
        repl_definition = {
          python = require('iron.fts.python').ipython,
        },
        repl_open_cmd = 'vsplit',
      },
      -- no `keymaps =`: see the spec's `keys` above
    }
  end,
}
