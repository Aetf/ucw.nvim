local A = vim.api
local F = vim.fn

local M = {}

M.url = 'rmagatti/auto-session'
M.description = 'Automatically save session based on path'

M.wants = { }

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.tui'
  }
}

-- allow at most one unnamed, unmodified buffer, closing all others
local function consolidate_unnamed()
  local consolidated = nil
  -- for any buf displayed in window, set to the first buf we encountered
  for _, win in pairs(A.nvim_list_wins()) do
    local buf = A.nvim_win_get_buf(win)
    if A.nvim_buf_get_name(buf) == '' and not vim.bo[buf].modified then
      if not consolidated then
        consolidated = buf
      end
      if buf ~= consolidated then
        A.nvim_win_set_buf(win, consolidated)
        A.nvim_buf_delete(buf, {})
      end
    end
  end

  -- for other remaining bufs, deleted them
  for _, buf in pairs(A.nvim_list_bufs()) do
    if A.nvim_buf_get_name(buf) == '' and not vim.bo[buf].modified and buf ~= consolidated then
      A.nvim_buf_delete(buf, {})
    end
  end
end

-- close aux windows that may interfere with session saving
local function close_aux_windows()
  local has_diffview, diffview_lib = pcall(require, 'diffview.lib')
  if has_diffview then
    for _, tab in pairs(A.nvim_list_tabpages()) do
      local view = diffview_lib.tabpage_to_view(tab)
      if view then
        view:close()
        diffview_lib.dispose_view(view)
      end
    end
  end

  for _, win in pairs(A.nvim_list_wins()) do
    local to_close = false
    -- close floating windows
    if A.nvim_win_get_config(win).relative > "" then
      to_close = true
    end

    local bufnr = A.nvim_win_get_buf(win)
    -- close drawer and tool windows
    local ft = vim.bo[bufnr].filetype
    if ft == 'fern' or ft == 'Trouble' or string.find(ft, 'tree') or string.find(ft, 'Neogit') then
      to_close = true
    end
    -- close helps
    local bt = vim.bo[bufnr].buftype
    if bt == 'help' then
      to_close = true
    end
    if to_close then
      A.nvim_win_close(win, true)
    end
  end
end

-- sometimes session messes with shortmess
local function restore_shortmess()
  vim.cmd[[set shortmess&]]
end

function M.config()
  require('auto-session').setup {
    log_level = 'warn',
    auto_restore_enabled = false,
    auto_session_suppress_dirs = {'~/', '/dev/shm', '/tmp'},
    pre_save_cmds = {
      close_aux_windows,
      consolidate_unnamed,
    },
    post_restore_cmds = {
      consolidate_unnamed,
      restore_shortmess,
    },
    bypass_session_save_file_types = {'neotree', 'help'},
  }
end

return M
