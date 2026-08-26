return {
  'akinsho/bufferline.nvim',
  cond = require('ucw.targets').is_full_ui,
  dependencies = { 'echasnovski/mini.nvim' },
  -- `keys` alone would flip the spec to lazy-loading; the bufferline has to
  -- exist from startup, so stay eager (Phase 8 relocates registration, not
  -- triggers). `<Tab>`/`<S-Tab>` are *not* here: their actions fall back to
  -- `:bnext`/`:bprev` without bufferline, so they are core keys
  -- (`which-key.lua`), not bufferline-owned.
  lazy = false,
  keys = {
    { '<C-PageDown>', '<cmd>BufferLineCycleNext<cr>', desc = 'Go To Next Buffer', silent = true },
    { '<C-PageUp>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Go To Previous Buffer', silent = true },
    { '<leader>bd', '<cmd>BufferLinePickClose<cr>', desc = 'Pick Buffer To Close', silent = true },
  },
  config = function()
    require('bufferline').setup {
      options = {
        separator_style = 'thin',
        always_show_bufferline = true,
        show_buffer_icons = true,
        show_close_icon = false,
        diagnostics = 'nvim_lsp',
        show_tab_indicators = true,
        -- tabpage indicator color is too washed out
        highlights = {
          tab_selected = {
            guifg = { highlight = 'Normal', attribute = 'fg' },
            guibg = { highlight = 'Normal', attribute = 'bg' },
            gui = 'bold,italic',
          },
        },
        sort_by = 'directory',
        -- do not draw over file tree
        offsets = {
          {
            filetype = 'neo-tree',
            text = 'Files',
            text_align = 'left',
          },
        },
        -- handle buf delete while preserving window layout
        close_command = function(buf_id)
          return require('ucw.utils').bufdelete(buf_id)
        end,
        middle_mouse_command = function(buf_id)
          return require('ucw.utils').bufdelete(buf_id)
        end,
        right_mouse_command = nil,
      },
    }
  end,
}
