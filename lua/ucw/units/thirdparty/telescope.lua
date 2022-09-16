local M = {}

M.url = 'nvim-telescope/telescope.nvim'
M.description = 'Fuzzy finder'

M.wants = {
  'plenary',
  'nvim-web-devicons', -- icons
  'treesitter', -- finder/preview
}
M.after = {
  'plenary',
}

-- ways to activate this
M.activation = {
  cmd = 'Telescope',
  wanted_by = {}
}

local utils = require('ucw.utils')

-- the same as telescope.actions.delete_buffer, but use our
-- window layout preserving bufdelete
local function safe_delete_buffer(prompt_bufnr)
  local action_state = require('telescope.actions.state')
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    utils.bufdelete(selection.bufnr)
  end)
end

function M.config()
  local telescope = require 'telescope'
  telescope.setup {
    defaults = {
      theme = 'dropdown',
      -- transparency in pop up window
      winblend = utils.is_gui() and 10 or 0,
      sorting_strategy = 'ascending',
      layout_strategy = 'flex',
      layout_config = {
        prompt_position = 'top'
      },
      mappings = {
        i = {
          -- close popup with esc, without going through normal mode
          ["<esc>"] = require('telescope.actions').close,
        },
      },
    },
    extensions = {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = 'smart_case',
      },
    },
    pickers = {
      buffers = {
        sort_lastused = true,
        sort_mru = true,
        previewer = false,
        mappings = {
          i = {
            ["<c-d>"] = safe_delete_buffer,
          }
        }
      },
    },
  }
end

return M
