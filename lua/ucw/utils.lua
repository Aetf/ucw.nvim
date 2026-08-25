local L = vim.loop
local o_s = vim.o
local map_key = vim.api.nvim_set_keymap
local au = require('au')

local M = {}

M.opt = function(o, v, scopes)
  scopes = scopes or { o_s }
  for _, s in ipairs(scopes) do
    s[o] = v
  end
end

M.map = function(modes, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap == nil and true or opts.noremap
  if type(modes) == 'string' then
    modes = { modes }
  end
  for _, mode in ipairs(modes) do
    map_key(mode, lhs, rhs, opts)
  end
end

M.is_gui = function()
  return vim.g.neovide or vim.g.nvui
end

local pager_mode = nil
function M.is_pager_mode()
  if pager_mode ~= nil then
    return pager_mode
  end
  -- `vim.fn.argv()` is annotated `string|string[]` because the zero-argument
  -- form returns the list and the one-argument form returns a single name;
  -- called with none, as here, it is always the list `next` wants.
  ---@diagnostic disable-next-line: param-type-mismatch
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
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == ''
end

-- Walk a window's jumplist away from the current position until landing in a
-- *different* normal buffer, and report how far that is.
--
-- `dir` is -1 for backward (the direction `<C-o>` moves) and 1 for forward
-- (`<C-i>`); `count` is how many distinct files to cross. Returns the number of
-- `<C-o>`/`<C-i>` presses that reach the landing entry, plus its buffer -
-- nothing if that direction runs out first.
--
-- The step count is the whole point: it is what lets a caller hand the jump
-- back to Neovim (`{steps}<C-o>`) instead of moving the cursor itself, so the
-- jumplist keeps being maintained by the code that owns it. Entries in the
-- current buffer and in non-normal buffers (terminals, quickfix, wiped ones)
-- are stepped over, not landed on, and still cost a press each.
---@param dir -1|1
---@return integer? steps, integer? target_buf
local function win_jump_other_buf(win, current_buf, dir, count)
  if current_buf == nil then
    current_buf = vim.api.nvim_win_get_buf(win)
  end
  count = count or 1

  -- `getjumplist()` returns `{list, idx}` - both at once, which is why this
  -- reads the pair rather than indexing twice. Doing the latter took `list[1]`
  -- (a single jump entry) for the list, so `#jumplist` was 0 for every window
  -- with a jumplist and this returned nothing at all.
  local jl = vim.fn.getjumplist(win)
  local jumps, idx = jl[1], jl[2]
  if jumps == nil or #jumps == 0 then
    return
  end

  -- `idx` is 0-based and is where `<C-o>`/`<C-i>` count from, so `steps`
  -- presses land on `jumps[idx + 1 + dir * steps]` in Lua's 1-based indexing.
  -- When the cursor sits past the newest entry, `idx` == `#jumps`, and one
  -- `<C-o>` reaches the last one.
  local remaining = count
  local last_buf = current_buf
  for steps = 1, #jumps do
    local i = idx + 1 + dir * steps
    if i < 1 or i > #jumps then
      return
    end
    local buf = jumps[i].bufnr
    if buf ~= last_buf and is_normal_buffer(buf) then
      remaining = remaining - 1
      if remaining == 0 then
        return steps, buf
      end
      last_buf = buf
    end
  end
end

-- find backward in jumplist until the buf is different
local function win_backward_buf(win, current_buf)
  local _, target_buf = win_jump_other_buf(win, current_buf, -1, 1)
  return target_buf
end

-- given a list of buffers, and current buffer's index in the list,
-- find the next normal buffer that is suitable to switch to
local function next_normal_buffer(buffers, current_buf)
  -- find current_buf's idx
  local current_idx = nil
  for i, v in ipairs(buffers) do
    if v == current_buf then
      current_idx = i
      break
    end
  end
  if current_idx == nil then
    vim.notify('current_buf not in buffers', vim.log.levels.ERROR, { title = '[ucw.utils] next_normal_buffer' })
    return
  end

  local cand_idx = wrap(current_idx + 1, #buffers)
  while cand_idx ~= current_idx do
    if is_normal_buffer(buffers[cand_idx]) then
      return buffers[cand_idx]
    end
    cand_idx = wrap(cand_idx + 1, #buffers)
  end

  -- if we end up here, it means no available normal buffer is available, we create a new one
  table.insert(buffers, vim.api.nvim_create_buf(true, false))
  return buffers[#buffers]
end

local function buf_kill(kill_cmd, bufnr, force)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- abort if buffer is modified and not force
  if not force and vim.bo[bufnr].modified then
    -- `nvim_echo` with `err = true` rather than `nvim_err_writeln`, which the
    -- C API deprecated (`:help deprecated`). Same behaviour: error-highlighted,
    -- kept in message history. Note `tests/test_deprecations.lua` structurally
    -- cannot see this one - it scans Neovim's *Lua* runtime for
    -- `vim.deprecate` calls, which is the right net for `vim.lsp.*` and the
    -- wrong one for `vim.api.*`. The lint gate is that test's complement.
    return vim.api.nvim_echo({
      { string.format('No write since last change for buffer %d (set force to true to override)', bufnr) },
    }, true, { err = true })
  end

  if force then
    kill_cmd = kill_cmd .. '!'
  end

  -- get list of windows with the buffer to close
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_buf(win) == bufnr
  end, vim.api.nvim_list_wins())

  if #windows > 0 then
    -- get list of active buffers
    local buffers = vim.api.nvim_list_bufs()

    -- set every win containing bufnr to next_buffer
    for _, win in ipairs(windows) do
      local next_buffer = nil

      -- try previous in jumplist
      if next_buffer == nil then
        next_buffer = win_backward_buf(win, bufnr)
      end

      -- try to use the window's alternate buffer first
      if next_buffer == nil then
        local alt_buf = vim.api.nvim_win_call(win, function()
          vim.fn.bufnr('#')
        end)
        if alt_buf and is_normal_buffer(alt_buf) then
          next_buffer = alt_buf
        end
      end

      -- find the next buffer, ignore plugin created buffers
      if next_buffer == nil then
        next_buffer = next_normal_buffer(buffers, bufnr)
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

M.win_jump_other_buf = win_jump_other_buf

M.bufdelete = function(bufnr, force)
  return buf_kill('bd', bufnr, force)
end

M.bufwipeout = function(bufnr, force)
  return buf_kill('bw', bufnr, force)
end

---Get the property `prop` specified as dot separated path from `obj`, creating empty table for
---all levels if not exists
function M.prop_get_table(obj, prop)
  for key in prop:gmatch('[^.]+') do
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
  local parent, key = string.match(prop, '(.+)%.([^%.]+)')
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

-- This is a bit of syntactic sugar for creating highlight groups over vim.api.nvim_set_hl.
-- Note that this currently always overrides the group rather than update the existing one.
--
-- local hi = require('ucw.utils').highlight
-- hi.Comment = { fg='#ffffff', bg='#000000', italic=true }
-- hi.LspDiagnosticsDefaultError = 'DiagnosticError' -- Link to another group
--
-- This is equivalent to the following vimscript
--
-- hi Comment guifg=#ffffff guibg=#000000 gui=italic
-- hi! link LspDiagnosticsDefaultError DiagnosticError
--
-- Or the following lua
--
-- vim.api.nvim_set_hl(0, 'Comment', { fg='#ffffff', bg='#000000', italic=true })
-- vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultError', { link='DiagnosticError'})
M.highlight = setmetatable({}, {
  __newindex = function(_, hlgroup, args)
    if 'string' == type(args) then
      vim.api.nvim_set_hl(0, hlgroup, { link = args })
      return
    else
      vim.api.nvim_set_hl(0, hlgroup, args)
    end
  end,
})

M.FileWatcher = {}

function M.FileWatcher.new(debounce_time)
  -- setup a luv fs event watcher on it, and a debounce time
  local this = setmetatable({
    timer = L.new_timer(),
    watcher = L.new_fs_event(),
    debouncing = false,
    path = nil,
    callback = nil,
    wrapped_cb = nil,
  }, { __index = M.FileWatcher })

  local weak_this = setmetatable({ this = this }, { __mode = 'v' })

  this.wrapped_cb = function(err, filename, events)
    -- take the weak ref and save to local so we don't lose it
    local that = weak_this.this
    if that == nil then
      return
    end

    if err ~= nil then
      vim.schedule(function()
        vim.notify(
          string.format('Watching:\n%s\nError:\n%s', that.path, err),
          vim.log.levels.ERROR,
          { title = '[ucw.utils] Error in libuv watcher' }
        )
      end)
      return
    end
    if not events.change and not events.rename then
      return
    end
    if that.debouncing or that.timer:is_active() then
      return
    end
    that.debouncing = true
    that.timer:start(
      debounce_time,
      0,
      vim.schedule_wrap(function()
        if that.callback ~= nil then
          that.callback(err, filename, events)
        end
        that.debouncing = false
      end)
    )

    -- refresh watcher so in case the file is renamed we still watch it
    that.watcher:stop()
    if that.path and that.callback then
      that.watcher:start(that.path, {}, that.wrapped_cb)
    end
  end

  return this
end

function M.FileWatcher:start(path, callback)
  self.path = path
  self.callback = callback
  if self.path and self.callback then
    self.watcher:start(self.path, {}, self.wrapped_cb)
  end
end

function M.FileWatcher:stop()
  self.path = nil
  self.callback = nil
  self.watcher:stop()
  self.timer:stop()
end

function M.FileWatcher:close()
  self:stop()
  self.watcher:close()
  self.timer:stop()
end

local setup_done = false
local function setup()
  if setup_done then
    return
  end
  au.group('Stdin', {
    {
      'StdinReadPre',
      '*',
      function()
        pager_mode = true
      end,
    },
  })
  setup_done = true
end

setup()

return M
