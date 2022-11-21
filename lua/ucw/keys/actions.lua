--[[
--Custom actions in one place
--]]
local utils = require('ucw.utils')
local t = utils.t


_G.UCW = {}
local M = {}
local H = {}

H.echo = function(msg, is_important)
  -- Construct message chunks
  msg = type(msg) == 'string' and { { msg } } or msg
  table.insert(msg, 1, { '(mini.ai) ', 'WarningMsg' })

  -- Avoid hit-enter-prompt
  local max_width = vim.o.columns * math.max(vim.o.cmdheight - 1, 0) + vim.v.echospace
  local chunks, tot_width = {}, 0
  for _, ch in ipairs(msg) do
    local new_ch = { vim.fn.strcharpart(ch[1], 0, max_width - tot_width), ch[2] }
    table.insert(chunks, new_ch)
    tot_width = tot_width + vim.fn.strdisplaywidth(new_ch[1])
    if tot_width >= max_width then break end
  end

  -- Echo. Force redraw to ensure that it is effective (`:h echo-redraw`)
  vim.cmd([[echo '' | redraw]])
  vim.api.nvim_echo(chunks, is_important, {})
end

H.unecho = function()
  if H.cache.msg_shown then vim.cmd([[echo '' | redraw]]) end
end

H.message = function(msg) H.echo(msg, true) end

H.error = function(msg) error(string.format('(ucw.keys.actions) %s', msg), 0) end

function M.bufdelete(bufnr, force)
  return utils.bufdelete( bufnr, force)
end

function M.bufwipeout(bufnr, force)
  return utils.bufwipeout( bufnr, force)
end

function M.bufnext()
  local ok = pcall(vim.cmd, 'BufferLineCycleNext')
  if not ok then
    vim.cmd [[bnext]]
  end
end

function M.bufprev()
  local ok = pcall(vim.cmd, 'BufferLineCyclePrev')
  if not ok then
    vim.cmd [[bprev]]
  end
end

local function diag_jump(direction)
  local trouble_method, vim_method = unpack(({
    next = {'next', 'goto_next'},
    prev = {'previous', 'goto_prev'}
  })[direction])

  local ok, trouble = pcall(require, 'trouble')
  if ok then
    -- if trouble returns nothing from items, then either trouble view isn't visible, or it's empty
    local items = trouble.get_items()
    if not vim.tbl_isempty(items) then
      return trouble[trouble_method]({ skip_groups = true, jump = true })
    end
  end
  return vim.diagnostic[vim_method]()
end

function M.diag_next()
  return diag_jump('next')
end

function M.diag_prev()
  return diag_jump('prev')
end

-- Send ipython cell under the current cursor to iron REPL.
-- If opts.next == true, move cursor to next cell.
function M.iron_send_block(opts)
  opts = opts or { next = false }
  -- TODO: figure out a way to directly call iron api
  vim.api.nvim_feedkeys(t'<leader>efih', 'mx', false)
  if opts.next then
    vim.cmd [[normal ]h]]
  end
end

-- Go to start obj mark, can be used as opfunc for textobj
function M.opfunc_textobj_go_start()
  vim.cmd 'normal! `['
end

-- Go to end obj mark, can be used as opfunc for textobj
function M.opfunc_textobj_go_end()
  vim.cmd 'normal! `]'
end

-- Invoke fold preview or lsp preview
function M.hoverK()
  local winid = nil
  local ok, ufo = pcall(require, 'ufo')
  if ok then
    winid = ufo.peekFoldedLinesUnderCursor()
  end
  if not winid then
    vim.lsp.buf.hover()
  end
end

-- Like the default Ctrl-L, but also clears nvim-notify
function M.clear()
  vim.cmd [[nohlsearch]]
  vim.cmd [[diffupdate]]
  -- Clear and redraw the screen
  -- See :h mode
  vim.cmd [[mode]]
  -- call notify in pcall to safely ignore any error
  pcall(function()
    require('notify').dismiss()
  end)
end

-- Jump between text objects
function H.user_textobject_id(ai_type)
  -- Get from user single character textobject identifier
  local needs_help_msg = true
  vim.defer_fn(function()
    if not needs_help_msg then return end

    local msg = string.format('Enter `%s` textobject identifier (single character) ', ai_type)
    H.echo(msg)
    H.cache.msg_shown = true
  end, 1000)
  local ok, char = pcall(vim.fn.getcharstr)
  needs_help_msg = false
  H.unecho()

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == '\27' then return nil end

  if char:find('^[%w%p%s]$') == nil then
    H.error('Input must be single character: alphanumeric, punctuation, or space.')
    return nil
  end

  return char
end
function M.jump_textobject(prev_next, left_right, ai_type)
  H.cache = {}

  local ok, ai = pcall(require, 'mini.ai')
  if not ok then
    H.error('No mini-ai found')
  end
  -- Get user input
  local tobj_id = H.user_textobject_id('a')
  if tobj_id == nil then return end

  -- Jump!
  ai.move_cursor(left_right, ai_type, tobj_id, { n_times = vim.v.count1, search_method = prev_next })
end
_G.UCW.jump_textobject = M.jump_textobject

return M
