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

-- `vim.diagnostic.goto_next`/`goto_prev`, which these used to call, are
-- deprecated for removal in 0.13 (runtime/lua/vim/diagnostic.lua:1562). Nobody
-- noticed because `g[`/`g]` were not actually mapped between Phase 1 and the
-- Phase 3 acceptance review (P3), so the line had not run in a month.
--
-- The old pair also defaulted to opening a float on arrival. Not restored:
-- Phase 4 made `virtual_lines = { current_line = true }` the way full
-- diagnostic text is shown, so the float would render the same message a second
-- time on top of it. `jump()`'s `opts.float` is itself deprecated in favour of
-- `on_jump`, so if that turns out to be wanted, that is where it goes.
--
-- What was here until now: a `pcall(require, 'trouble')` branch that preferred
-- trouble.nvim's own next/previous when its list had items. trouble is not a
-- spec in `lua/ucw/plugins/` and is not in `lazy-lock.json` - measured, the
-- `pcall` returns false - so the branch had been unreachable since long before
-- this config's Phase 0, which was supposed to delete exactly this kind of
-- thing (second-round review, Q4).

function M.diag_next()
  return vim.diagnostic.jump({ count = 1 })
end

function M.diag_prev()
  return vim.diagnostic.jump({ count = -1 })
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

-- Toggle full diagnostic text rendered below the line, between "current line
-- only" and "every line in the buffer".
--
-- Was lsp_lines.nvim, which replaced core's `virtual_lines` handler with its
-- own; core renders the same thing now, so only the toggle survives. The option
-- is `current_line` - lsp_lines spelled it `only_current_line`, and the old
-- toggle kept writing that name, which core silently ignores.
function M.toggle_virtual_lines()
  local enabled = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config {
    virtual_lines = enabled and { current_line = true } or false,
  }
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
