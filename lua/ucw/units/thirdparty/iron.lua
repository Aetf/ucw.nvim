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
  local iron = require('iron')

  iron.core.set_config {
    highlight_last = false,
    preferred = {
      python = 'ipython'
    }
  }

  local wk = require('which-key')
  wk.register({
    e = {
      name = '+eval',
      ['f'] = { [[<Plug>(iron-send-motion)]], "Send motion to REPL" },
      ['F'] = { [[<Plug>(iron-send-line)]], "Send line to REPL" },
      ['<CR>'] = { [[<Plug>(iron-cr)]], "Send a newline to REPL" },

      ['.'] = { [[<Plug>(iron-repeat-cmd)]], "Repeat the last command" },
      q = { [[<Plug>(iron-exit)]], "Exit REPL" },
      c = { [[<Plug>(iron-interrupt)]], "Send an interrupt to REPL" },
      l = { [[<Plug>(iron-clear)]], "Clear the REPL" },
    }
  }, { prefix = '<leader>' })
  wk.register({
    e = {
      name = "+eval",
      ['f'] = { [[<Plug>(iron-visual-send)]], "Send selected to REPL" },
    }
  }, { prefix = '<leader>', mode = 'v'})
  for _, m in pairs({'n', 'v', 'i'}) do
    wk.register({
      ['<S-Enter>'] = { [[<cmd>lua require('ucw.keys.actions').iron_send_block({next=true})<cr>')]], "Send block to REPL and move to next" },
      -- ['<C-Enter>'] = { [[<cmd>lua require('ucw.keys.actions').iron_send_block()<cr>')]], "Send block to REPL" },
      ['<C-Enter>'] = { [[<Plug>(iron-send-motion)ih]], "Send block to REPL" },
    }, { mode = m })
  end
end

return M
