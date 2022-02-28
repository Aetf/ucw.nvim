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

function M.diag_next()
  local ok, trouble = pcall(require, 'trouble')
  if ok then
    -- trouble doesn't have an API to check if it's open or not, so
    -- we just try
    local opts = { skip_groups = true, jump = true }

    ok, _ = pcall(trouble.next, opts)
    if ok then
      return
    end
  end
  vim.diagnostic.goto_next()
end

function M.diag_prev()
  local ok, trouble = pcall(require, 'trouble')
  if ok then
    -- trouble doesn't have an API to check if it's open or not, so
    -- we just try
    local opts = { skip_groups = true, jump = true }

    ok, _ = pcall(trouble.previous, opts)
    if ok then
      return
    end
  end
  vim.diagnostic.goto_prev()
end

return M
