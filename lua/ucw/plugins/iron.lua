return {
  'hkupty/iron.nvim',
  -- `keys` alone would flip the spec to lazy-loading; iron's own `<leader>e`
  -- keymaps only exist once `setup()` runs, so stay eager (Phase 8 relocates
  -- registration, not triggers).
  lazy = false,
  -- Phase 8 (D1/D4): the `wk.add` block in `config()` became these entries,
  -- minus a real defect: both rhs strings ended in a stray `')` *after* the
  -- `<cr>`, two leftover characters that got fed as keys every press.
  -- Measured before fixing: in insert mode (both maps include it) the buffer
  -- literally gained `')`.
  keys = {
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
      keymaps = {
        send_motion = '<leader>ef',
        visual_send = '<leader>ef',
        send_file = '<leader>e%',
        send_line = '<leader>eF',
        cr = '<leader>e<cr>',
        interrupt = '<leader>ec',
        exit = '<leader>eq',
        clear = '<leader>el',
      },
    }
  end,
}
