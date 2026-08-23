--[[
--Custom actions in one place
--]]
local utils = require('ucw.utils')
local t = utils.t

local M = {}

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

-- Diagnostic navigation lives on Neovim's own `[d`/`]d`/`[D`/`]D` (Phase 9.5,
-- T6). The wrappers that were here are gone: the defaults call the same
-- `vim.diagnostic.jump()` and additionally honour a count. No float on arrival
-- in either version, which is what this config wants - Phase 4 made
-- `virtual_lines = { current_line = true }` the way full diagnostic text is
-- shown, so a float would render the same message a second time on top of it.

-- Previous / next ipython cell, the `[`/`]` form every other sequence in this
-- config uses. Bound buffer-locally in `ftplugin/python.lua`: the `# %%` mark
-- these jump between is a Python comment, and the textobject that finds it
-- (`ucw.textobjects.ipython`, registered as mini.ai's `h`/`H`) has nothing to
-- match in any other filetype.
---@param dir 'prev'|'next'
function M.cell_jump(dir)
  require('mini.ai').move_cursor('left', 'a', 'h', { n_times = vim.v.count1, search_method = dir })
end

-- Send ipython cell under the current cursor to iron REPL.
-- If opts.next == true, move cursor to next cell.
function M.iron_send_block(opts)
  opts = opts or { next = false }
  -- TODO: figure out a way to directly call iron api
  -- `<leader>rs` + the `ih` cell textobject (Phase 9, D5: was `<leader>ef`)
  vim.api.nvim_feedkeys(t('<leader>rsih'), 'mx', false)
  if opts.next then
    -- `M.cell_jump`, not `:normal ]h`: this is bound to `<S-Enter>` globally,
    -- and `]h` only exists in a python buffer. The mapping was never there to
    -- press either - it was written against mini.ai's `goto_*` keys after
    -- those had been disabled, so the advance half of `<S-Enter>` had been a
    -- no-op ever since (Phase 9.5, T6).
    M.cell_jump('next')
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

return M
