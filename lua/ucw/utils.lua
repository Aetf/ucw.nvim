local L = vim.loop
local o_s = vim.o
local map_key = vim.api.nvim_set_keymap
local au = require('au')

local M = {}

M.opt = function(o, v, scopes)
  scopes = scopes or {o_s}
  for _, s in ipairs(scopes) do s[o] = v end
end

M.map = function(modes, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap == nil and true or opts.noremap
  if type(modes) == 'string' then modes = {modes} end
  for _, mode in ipairs(modes) do map_key(mode, lhs, rhs, opts) end
end

M.is_gui = function()
  return vim.g.neovide or vim.g.nvui
end

local pager_mode = nil
function M.is_pager_mode()
  if pager_mode ~= nil then
    return pager_mode
  end
  local opened_with_args = next(vim.fn.argv()) ~= nil -- Neovim was opened with args

  pager_mode = pager_mode or opened_with_args
  return pager_mode
end

function M.is_dir(path)
  local stats = L.fs_stat(path)
  return stats and stats.type == 'directory'
end


-- 1-based wraping
local function wrap(num, total)
  return (num - 1) % total + 1
end

-- if the buffer is a normal text file based buffer
local function is_normal_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
end

local function buf_kill(kill_cmd, bufnr, force)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- abort if buffer is modified and not force
  if not force and vim.bo[bufnr].modified then
    return vim.api.nvim_err_writeln(
      string.format('No write since last change for buffer %d (set force to true to override)', bufnr)
    )
  end

  if force then
    kill_cmd = kill_cmd .. '!'
  end

  -- get list of windows with the buffer to close
  local windows = vim.tbl_filter(
    function(win) return vim.api.nvim_win_get_buf(win) == bufnr end,
    vim.api.nvim_list_wins()
  )

  if #windows > 0 then
    -- get list of active buffers, ignoring plugin buffers
    local buffers = vim.tbl_filter(
      is_normal_buffer,
      vim.api.nvim_list_bufs()
    )

    -- if there's only one buffer (which has to be the current one),
    -- we need to create a new one
    if #buffers == 1 then
      buffers[#buffers+1] = vim.api.nvim_create_buf(true, false)
    end
    -- find the next buffer
    local next_buffer = nil
    for i, v in ipairs(buffers) do
      if v == bufnr then
        next_buffer = buffers[wrap(i + 1, #buffers)]
        break
      end
    end
    for _, win in ipairs(windows) do
      -- try to use the window's alternate buffer first
      local alt_buf = vim.api.nvim_win_call(win, function() vim.fn.bufnr('#') end)
      if alt_buf and is_normal_buffer(alt_buf) then
        next_buffer = alt_buf
      end
      vim.api.nvim_win_set_buf(win, next_buffer)
    end
  end

  -- check if buffer still exists, to ensure the target buffer wasn't killed
  -- due to options like bufhidden=wipe
  if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
    vim.cmd(string.format('%s %d', kill_cmd, bufnr))
  end
end

M.bufdelete = function(bufnr, force)
  return buf_kill('bd', bufnr, force)
end

M.bufwipeout = function(bufnr, force)
  return buf_kill('bw', bufnr, force)
end

---Get the property `prop` specified as dot separated path from `obj`, creating empty table for
---all levels if not exists
function M.prop_get_table(obj, prop)
  for key in prop:gmatch "[^.]+" do
    if obj[key] == nil then
      obj[key] = {}
    end
    obj = obj[key]
  end
  return obj
end

---Get the property `prop` specified as dot separated path from `obj`,
---creating empty table if not exists for all levels except the last
---level, which is set to val
function M.prop_set(obj, prop, val)
  -- get the parent level as table
  local parent, key = string.match(prop, "(.+)%.([^%.]+)")
  if not parent or not key then
    -- assume prop is the key directly
    obj[prop] = val
  else
    M.prop_get_table(obj, parent)[key] = val
  end
end

---table.insert but skip if already contains the value
function M.tbl_insert_uniq(tbl, val)
  if not vim.tbl_contains(tbl, val) then
    table.insert(tbl, val)
  end
end

-- The function is called `t` for `termcodes`.
-- You don't have to call it that, but I find the terseness convenient
function M.t(str)
    -- Adjust boolean arguments as needed
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local setup_done = false
local function setup()
  if setup_done then
    return
  end
  au.group('Stdin', {
    { 'StdinReadPre', '*', function() pager_mode = true end }
  })
  setup_done = true
end

setup()

return M
