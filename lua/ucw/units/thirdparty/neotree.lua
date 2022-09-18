local M = {}

M.url = 'nvim-neo-tree/neo-tree.nvim'
M.description = 'Neovim plugin to manage the file system and other tree like structures.'
M.install_opts = {
  branch = 'v2.x'
}

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

-- temporary fix for diagnostic component to use neovim's new DiagnosticSign* series of signs
local sev_mapping = {
  Error = 'Error',
  Warning = 'Warn',
  Information = 'Info',
  Hint = 'Hint',
}

local function comp_diag(config, node, state)
  local diag = state.diagnostics_lookup or {}
  local diag_state = diag[node:get_id()]
  if not diag_state then
    return {}
  end
  if config.errors_only and diag_state.severity_number > 1 then
    return {}
  end
  local severity = sev_mapping[diag_state.severity_string] or diag_state.severity_string
  local defined = vim.fn.sign_getdefined("DiagnosticSign" .. severity)
  defined = defined and defined[1]
  if defined and defined.text and defined.texthl then
    return {
      text = " " .. defined.text,
      highlight = defined.texthl,
    }
  else
    return {
      text = " " .. severity:sub(1, 1),
      highlight = "Diagnostic" .. severity,
    }
  end
end

local au = require('au')
local t = require('ucw.utils').t

function M.config()
  vim.g.neo_tree_remove_legacy_commands = 1
  require("neo-tree").setup({
    close_if_last_window = true,
    hide_root_node = true,
    -- use vim.ui.input for inputs, which will be dressed up by dressing.vim
    use_popups_for_input = false,
    event_handlers = {
      {
        event = "file_opened",
        handler = function(file_path)
          --clear search after opening a file
          require("neo-tree.sources.filesystem").reset_search()
        end
      },
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
      components = {
        diagnostics = comp_diag,
      },
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
          ["o"] = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            -- open file in default application in the background
            vim.api.nvim_command("silent !xdg-open " .. path)
          end,
          ["h"] = "open_vsplit",
          ["v"] = "open_split",
          -- Move to first/last sibling
          ["J"] = function(state)
            local tree = state.tree
            local node = tree:get_node()
            local siblings = tree:get_nodes(node:get_parent_id())
            local renderer = require('neo-tree.ui.renderer')
            renderer.focus_node(state, siblings[#siblings]:get_id())
          end,
          ["K"] = function(state)
            local tree = state.tree
            local node = tree:get_node()
            local siblings = tree:get_nodes(node:get_parent_id())
            local renderer = require('neo-tree.ui.renderer')
            renderer.focus_node(state, siblings[1]:get_id())
          end,
          -- Enable lightspeed movement
          -- 'm' flag tells vim to remap keys
          -- 'x!' flag tells vim not to automatically append <esc> to end the mode so this actually works
          ["S"] = function(state) vim.api.nvim_feedkeys(t([[<Plug>Lightspeed_S]]), 'mx!', true) end,
          ["s"] = function(state) vim.api.nvim_feedkeys(t([[<Plug>Lightspeed_omni_s]]), 'mx!', true) end,
        },
      },
      commands = {
      },
    },
  })


  local wk = require('which-key')
  wk.register {
    ['|'] = { [[<cmd>NeoTreeRevealToggle<cr>]], "Toggle file tree (focus)" },
    ['\\'] = { [[<cmd>NeoTreeShowToggle<cr>]], "Toggle file tree" },
    ['<leader>f'] = {
      name = "+file tree",
      f = { [[<cmd>NeoTreeFocus<cr>]], "Focuse file tree" },
      o = { [[<cmd>NeoTreeFocus<cr>]], "Open file tree" },
    }
  }
end

return M
