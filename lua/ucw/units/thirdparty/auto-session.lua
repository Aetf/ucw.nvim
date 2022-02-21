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

local function close_nvimtree()
  vim.cmd [[tabdo NvimTreeClose]]
end

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

-- sometimes NvimTree leaves behind a buffer named `[NvimTree]` after restoring,
-- despite we close it before saving the session.
local function remove_nvimtree()
  for _, buf in pairs(A.nvim_list_bufs()) do
    local name = A.nvim_buf_get_name(buf)
    if name == 'NvimTree' or F.fnamemodify(name, ':t') == 'NvimTree' then
      A.nvim_buf_delete(buf, {})
    end
  end
end

-- close aux windows that may interfere with session saving
local function close_aux_windows()
  for _, win in pairs(A.nvim_list_wins()) do
    if A.nvim_win_get_config(win).relative > "" then
      -- close floating windows
      A.nvim_win_close(win, true)
    else
      -- close drawer and tool windows
      local ft = vim.bo[A.nvim_win_get_buf(win)].filetype
      if ft == 'fern' or ft == 'Trouble' or string.find(ft, 'tree') then
        A.nvim_win_close(win, true)
      end
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
    auto_session_suppress_dirs = {'~/', '/dev/shm', '/tmp'},
    pre_save_cmds = {
      close_aux_windows,
      remove_nvimtree,
      consolidate_unnamed,
    },
    post_restore_cmds = {
      remove_nvimtree,
      consolidate_unnamed,
      restore_shortmess,
    },
    bypass_session_save_file_types = {'neotree', 'help'},
  }
end

return M
