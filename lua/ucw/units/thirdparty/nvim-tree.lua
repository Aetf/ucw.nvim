local M = {}

M.url = 'kyazdani42/nvim-tree.lua'
M.description = 'File tree'

M.wants = {
  'nvim-web-devicons',
}
M.after = {
  'nvim-web-devicons',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

local A = vim.api
local cmd = vim.cmd
local au = require('au')
local utils = require('ucw.utils')

function M.config()
  vim.g.nvim_tree_indent_markers = 1
  vim.g.nvim_tree_git_hl = 1
  vim.g.nvim_tree_highlight_opened_files = 3
  vim.g.nvim_tree_group_empty = 1
  vim.g.nvim_tree_add_trailing = 1
  vim.g.nvim_tree_respect_buf_cwd = 1
  vim.g.nvim_tree_root_folder_modifier = ':~:.'
  vim.g.nvim_tree_tree_show_icons = {
    files = 1,
    folders = 1,
    folder_arrows = 1,
    git = 1,
  }
  local ntree = require('nvim-tree')
  ntree.setup {
    hijack_cursor = true,
    -- this is buggy, see https://github.com/kyazdani42/nvim-tree.lua/issues/894
    auto_close = false,
    -- use our own open on dir beheavior
    open_on_setup = false,
    update_cwd = true,
    update_focused_file = {
      enable = true,
    },
    -- this interfers with our open on startup
    update_to_buf_dir = {
      enable = false,
    },
    diagnostics = {
      enable = true,
    },
    view = {
      auto_resize = true,
      hide_root_folder = true,
    },
  }

  -- also fix cursor position when initially enter the buffer,
  -- in addition to hijack_cursor, which only fixes cursor position while moving
  au.group('NvimTreeCursorFix', {
    {
      'BufWinEnter', 'NvimTree', ntree.place_cursor_on_node
    }
  })
  -- nvim-tree only completes its setup after a while, so do the whole thing in schedule
  if not utils.is_pager_mode() then
    vim.schedule(function()
      local oldb = A.nvim_get_current_buf()
      local win = A.nvim_get_current_win()
      local path = A.nvim_buf_get_name(oldb)
      if utils.is_dir(path) then
        -- when open a directory, show scratch in middle and file tree on side
        cmd('lcd ' .. path)
        ntree.open()
        local buf = A.nvim_create_buf(true, false)
        A.nvim_win_set_buf(win, buf)
        A.nvim_set_current_win(win)
        A.nvim_buf_delete(oldb, {})
      else
        -- in all other cases, simply show file tree
        ntree.open()
        A.nvim_set_current_win(win)
      end
    end)
  end
end

return M
