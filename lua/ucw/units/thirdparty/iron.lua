local M = {}

M.url = 'hkupty/iron.nvim'
M.description = 'Iron REPL'

M.requires = {
  'which-key'
}
M.after = {
  'which-key'
}
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.setup()
  -- we define our own mapping
  vim.g.iron_map_defaults = 0
  vim.g.iron_map_extended = 0
end

function M.config()
  local iron = require('iron.core')

  iron.setup {
    config = {
      scratch_repl = false,
      highlight_last = false,
      should_map_plug = false,
      repl_definition = {
        python = require('iron.fts.python').ipython,
      },
      -- repl_open_cmd = require('iron.view').curry.right(function() return math.floor(vim.o.columns * 0.4) end),
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
    }
  }

  local wk = require('which-key')
  wk.add {
    {
      mode = { 'n', 'v', 'i' },
      { "<C-Enter>", "<cmd>lua require('ucw.keys.actions').iron_send_block()<cr>')", desc = "Send block to REPL" },
      { "<S-Enter>", "<cmd>lua require('ucw.keys.actions').iron_send_block({next=true})<cr>')", desc = "Send block to REPL and move to next"},
    }
  }
end

return M
