local M = {}

M.url = 'nvim-neo-tree/neo-tree.nvim'
M.description = 'Neovim plugin to manage the file system and other tree like structures.'

M.requires = {
  "plenary",
  "nui",
  'which-key',
}
M.wants = {
  "nvim-web-devicons",
  'dressing', -- for rename input
}
M.after = {
  "plenary",
  "nvim-web-devicons",
  "nui",
  'which-key',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

function M.config()
  -- See ":help neo-tree-highlights" for a list of available highlight groups
  vim.cmd([[
    hi link NeoTreeDirectoryName Function
    hi link NeoTreeDirectoryIcon NeoTreeDirectoryName
    hi link NeoTreeDimText Whitespace
  ]])

  require("neo-tree").setup({
    close_if_last_window = true,
    -- use vim.ui.input for inputs, which will be dressed up by dressing.vim
    use_popups_for_input = false,
    default_component_configs = {
      indent = {
        indent_size = 2,
        padding = 0, -- extra padding on left hand side
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeDimText",
      },
      name = {
        trailing_slash = true,
      },
    },
    filesystem = {
      -- This will find and focus the file in the active buffer every
      -- time the current file is changed while the tree is open.
      follow_current_file = true,
      -- This will use the OS level file watchers
      -- to detect changes instead of relying on nvim autocmd events.
      use_libuv_file_watcher = true,
      window = {
        -- dynamic width fitting the content
        width = function(state)
          local root_name = vim.fn.fnamemodify(state.path, ":~")
          local root_len = string.len(root_name) + 4
          return math.max(root_len, 30)
        end,

        mappings = {
          ["o"] = "system_open",
        },
      },
      commands = {
        system_open = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          -- open file in default application in the background
          vim.api.nvim_command("silent !xdg-open " .. path)
        end,
      },
    },
  })


  local wk = require('which-key')
  wk.register {
    ['\\'] = { [[<cmd>NeoTreeRevealToggle<cr>]], "Toggle file tree" },
    ['<leader>f'] = {
      name = "+file tree",
      f = { [[<cmd>NeoTreeFocus<cr>]], "Focuse file tree" },
      o = { [[<cmd>NeoTreeFocus<cr>]], "Open file tree" },
    }
  }
end

return M
