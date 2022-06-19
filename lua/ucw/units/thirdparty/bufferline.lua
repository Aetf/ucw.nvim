local M = {}

M.url = 'akinsho/bufferline.nvim'
M.description = 'Tab bar'

M.wants = {
  'nvim-web-devicons',
}

M.activation = {
  wanted_by = {
    'target.tui'
  }
}

function M.config()
  require('bufferline').setup {
    options = {
      separator_style = 'thin',
      always_show_bufferline = true,
      show_buffer_icons = true,
      show_close_icon = false,
      diagnostics = 'nvim_lsp',
      diagnostics_update_in_insert = true,
      show_tab_indicators = true,
      -- tabpage indicator color is too washed out
      highlights = {
        tab_selected = {
          guifg = { highlight = 'Normal', attribute = 'fg' },
          guibg = { highlight = 'Normal', attribute = 'bg' },
          gui = "bold,italic",
        }
      },
      -- numbers = function(opts)
      -- return string.format('%s%s', opts.id, opts.lower(opts.ordinal))
      -- end,
      sort_by = 'directory',
      -- do not draw over file tree
      offsets = {
        {
          filetype = 'neo-tree',
          text = 'Files',
          -- highlight = 'Directory',
          text_align = "left",
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
end

return M
