--[[
--Custom actions in one place
--]]
local utils = require('ucw.utils')

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
    vim.notify('Got trouble items ' .. vim.inspect(items))
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

return M
