--[[
--Custom actions in one place
--]]
local utils = require('ucw.utils')
local t = utils.t

local M = {}

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

return M
