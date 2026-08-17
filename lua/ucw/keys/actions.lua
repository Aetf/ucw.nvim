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
    if tot_width >= max_width then
      break
    end
  end

  -- Echo. Force redraw to ensure that it is effective (`:h echo-redraw`)
  vim.cmd([[echo '' | redraw]])
  vim.api.nvim_echo(chunks, is_important, {})
end

H.unecho = function()
  if H.cache.msg_shown then
    vim.cmd([[echo '' | redraw]])
  end
end

H.message = function(msg)
  H.echo(msg, true)
end

H.error = function(msg)
  error(string.format('(ucw.keys.actions) %s', msg), 0)
end

function M.bufdelete(bufnr, force)
  return utils.bufdelete(bufnr, force)
end

function M.bufwipeout(bufnr, force)
  return utils.bufwipeout(bufnr, force)
end

-- `vim.cmd` is a callable *table*, not a function, so `pcall`'s `fun(...)`
-- parameter type rejects it while `pcall` itself is perfectly happy with
-- anything that has a `__call`. Same suppression on `bufprev` below.
function M.bufnext()
  ---@diagnostic disable-next-line: param-type-mismatch
  local ok = pcall(vim.cmd, 'BufferLineCycleNext')
  if not ok then
    vim.cmd([[bnext]])
  end
end

function M.bufprev()
  ---@diagnostic disable-next-line: param-type-mismatch
  local ok = pcall(vim.cmd, 'BufferLineCyclePrev')
  if not ok then
    vim.cmd([[bprev]])
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
  return vim.diagnostic.jump { count = 1 }
end

function M.diag_prev()
  return vim.diagnostic.jump { count = -1 }
end

-- Send ipython cell under the current cursor to iron REPL.
-- If opts.next == true, move cursor to next cell.
function M.iron_send_block(opts)
  opts = opts or { next = false }
  -- TODO: figure out a way to directly call iron api
  -- `<leader>rs` + the `ih` cell textobject (Phase 9, D5: was `<leader>ef`)
  vim.api.nvim_feedkeys(t('<leader>rsih'), 'mx', false)
  if opts.next then
    vim.cmd([[normal ]h]])
  end
end

-- The diagnostic virtual-lines toggle that lived here (`toggle_virtual_lines`,
-- the remnant of lsp_lines.nvim) is a `Snacks.toggle` in `ucw.toggles` now
-- (Phase 8, D2), history and all.

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

-- Does what the default `<C-l>` does, plus dismisses anything noice is showing.
--
-- Bound to **`<Esc>` in normal mode** (`ucw/keys.lua`), not to `<C-l>` - the
-- old comment said "like the default Ctrl-L" and that reads as *where* it is
-- bound. It is not; `<C-l>` is still Neovim's own. So this runs on one of the
-- most-pressed keys there is, and everything in it has to be cheap and safe to
-- repeat.
function M.clear()
  vim.cmd([[nohlsearch]])
  vim.cmd([[diffupdate]])
  -- Clear and redraw the screen
  -- See :h mode
  vim.cmd([[mode]])
  -- noice rather than the notifier directly: it dismisses its own views *and*,
  -- through `SnacksView.dismiss`, calls `Snacks.notifier.hide()`. Kept in a
  -- pcall to safely ignore any error, as the nvim-notify version was.
  --
  -- This is wider than the `require('notify').dismiss()` it replaced - it takes
  -- down every noice view, not just the toasts - which on `<Esc>` is the
  -- intent, and it is safe to do this often: `Router.dismiss()` starts with
  -- `Manager.clear()`, but that empties only the *live* set (`_messages`).
  -- Browsable history lives in `Manager._history`, which nothing here touches.
  -- Measured, three messages held: `<Esc>` leaves `:Noice`/`<leader>nn` at 3.
  pcall(function()
    require('noice').cmd('dismiss')
  end)
end

-- Jump between text objects
function H.user_textobject_id(ai_type)
  -- Get from user single character textobject identifier
  local needs_help_msg = true
  vim.defer_fn(function()
    if not needs_help_msg then
      return
    end

    local msg = string.format('Enter `%s` textobject identifier (single character) ', ai_type)
    H.echo(msg)
    H.cache.msg_shown = true
  end, 1000)
  local ok, char = pcall(vim.fn.getcharstr)
  needs_help_msg = false
  H.unecho()

  -- Terminate if couldn't get input (like with <C-c>) or it is `<Esc>`
  if not ok or char == '\27' then
    return nil
  end

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
  if tobj_id == nil then
    return
  end

  -- Jump!
  ai.move_cursor(left_right, ai_type, tobj_id, { n_times = vim.v.count1, search_method = prev_next })
end
_G.UCW.jump_textobject = M.jump_textobject

return M
