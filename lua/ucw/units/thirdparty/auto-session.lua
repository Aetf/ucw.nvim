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

-- sometimes NvimTree leaves behind a buffer named `[NvimTree]` after restoring,
-- despite we close it before saving the session.
local function remove_nvimtree()
  for _, buf in pairs(A.nvim_list_bufs()) do
    local name = A.nvim_buf_get_name(buf)
    print(string.format('Got buf %d: %s, %s', buf, name, F.fnamemodify(name, ':t')))
    if name == 'NvimTree' or F.fnamemodify(name, ':t') == 'NvimTree' then
      A.nvim_buf_delete(buf, {})
    end
  end
end

function M.config()
  require('auto-session').setup {
    auto_session_suppress_dirs = {'~/', '~/develop', '/dev/shm', '/tmp'},
    pre_save_cmds = {
      'tabdo NvimTreeClose',
    },
    post_restore_cmds = {
      consolidate_unnamed,
      remove_nvimtree
    }
  }
end

return M
