local M = {}

function M.setup()
  vim.g.neo_tree_remove_legacy_commands = 1
end

function M.config()
  local helpers = require('ucw.neotree.helpers')

  require("neo-tree").setup({
    close_if_last_window = true,
    hide_root_node = true,
    -- use vim.ui.input for inputs, which will be dressed up by dressing.vim
    use_popups_for_input = false,
    event_handlers = {
      {
        event = 'neo_tree_buffer_enter',
        handler = function()
          -- tweak buffer local settings
          vim.opt_local.signcolumn = 'no'
          vim.opt_local.number = true
          vim.opt_local.relativenumber = true
          vim.opt_local.foldcolumn = '0'
        end
      }
    },
    default_component_configs = {
      indent = {
        -- extra padding on left hand side
        padding = 0,
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
      use_libuv_file_watcher = false,
      window = {
        -- dynamic width fitting the content
        width = helpers.width_fit_content,

        mappings = {
          ["O"] = 'system_open',
          ["o"] = 'none',
          ["oh"] = "open_vsplit",
          ["ov"] = "open_split",
          -- Move to first/last sibling
          ["J"] = 'first_sibling',
          ["K"] = 'last_sibling',
          -- Horizontal moves control dir open/close
          ['h'] = 'move_out',
          ['l'] = 'move_in',

          -- Enable lightspeed movement
          -- 'm' flag tells vim to remap keys
          -- 'x!' flag tells vim not to automatically append <esc> to end the mode so this actually works
          ["S"] = function(state) vim.api.nvim_feedkeys(t([[<Plug>Lightspeed_S]]), 'mx!', true) end,
          ["s"] = function(state) vim.api.nvim_feedkeys(t([[<Plug>Lightspeed_omni_s]]), 'mx!', true) end,
          -- Emulating Vim's fold commands
          ["z"] = "none",

          ["zo"] = 'neotree_zo',
          ["zO"] = 'neotree_zO',
          ["zc"] = 'neotree_zc',
          ["zC"] = 'neotree_zC',
          ["za"] = 'neotree_za',
          ["zA"] = 'neotree_zA',
          ["zx"] = 'neotree_zx',
          ["zX"] = 'neotree_zX',
          ["zm"] = 'neotree_zm',
          ["zM"] = 'neotree_zM',
          ["zr"] = 'neotree_zr',
          ["zR"] = 'neotree_zR',
        },
      },
      commands = helpers.commands,
    },
  })

  vim.keymap.set('n', '|', [[<cmd>Neotree action=focus toggle=true reveal=true<cr>]], {
    desc = 'Toggle file tree (focus)',
  })
  vim.keymap.set('n', '\\', [[<cmd>Neotree action=show toggle=true reveal=true<cr>]], {
    desc = 'Toggle file tree',
  })
end

return M
