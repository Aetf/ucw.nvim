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

local function config()
  local telescope = require('telescope')
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
  telescope.load_extension('fzf')
  -- optional integrations, only load if the other plugin is present
  pcall(telescope.load_extension, 'notify')
end

return {
  'nvim-telescope/telescope.nvim',
  cmd = 'Telescope',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'echasnovski/mini.nvim',
    'nvim-treesitter/nvim-treesitter',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },
  config = config,
}
