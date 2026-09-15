--[[
--Custom actions in one place
--]]
local utils = require('ucw.utils')

local M = {}

function M.bufdelete(bufnr, force)
  return utils.bufdelete(bufnr, force)
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
-- in either version, which is what this config wants: the message is one `K`
-- (or `<leader>uv`, virtual lines) away when it is wanted, and a float that
-- appears on every jump is in the way when it is not.

-- Previous / next ipython cell, the `[`/`]` form every other sequence in this
-- config uses. Bound buffer-locally in `ftplugin/python.lua`: the `# %%` mark
-- these jump between is a Python comment, and the textobject that finds it
-- (`ucw.textobjects.ipython`, registered as mini.ai's `h`/`H`) has nothing to
-- match in any other filetype.
---@param dir 'prev'|'next'
function M.cell_jump(dir)
  require('mini.ai').move_cursor('left', 'a', 'h', { n_times = vim.v.count1, search_method = dir })
end

-- One `<C-o>`/`<C-i>` step at file granularity: go to the nearest jumplist
-- entry that is in another file, which is what holding the native key down
-- until the name in the statusline changes does by hand. Bound to the same
-- keys with Shift (`ucw.keys`).
--
-- The jump itself is Neovim's - this only works out *how many* presses reach
-- that entry and hands `{steps}<C-o>` back to `normal!`. Anything that moved
-- the cursor directly (`nvim_win_set_cursor`, `:buffer`) would leave the
-- jumplist describing a history that never happened.
---@param dir -1|1 backward (`<C-o>`) or forward (`<C-i>`)
function M.jump_file(dir)
  local steps = utils.win_jump_other_buf(0, nil, dir, vim.v.count1)
  if steps == nil then
    return vim.notify(
      dir < 0 and 'No earlier file in the jumplist' or 'No later file in the jumplist',
      vim.log.levels.INFO,
      { title = 'jumplist' }
    )
  end
  vim.cmd.normal { steps .. vim.keycode(dir < 0 and '<C-o>' or '<C-i>'), bang = true }
end

-- Send ipython cell under the current cursor to iron REPL.
-- If opts.next == true, move cursor to next cell.
function M.iron_send_block(opts)
  opts = opts or { next = false }
  -- The cell is resolved with mini.ai's public lookup (the same `ih` spec
  -- the textobject key uses) and handed to iron directly. Not
  -- `feedkeys('<leader>rsih')`: when the `<leader>rs` wrapper declined (no
  -- REPL binary) the leftover `ih` ran as normal-mode input and typed an
  -- `h` into the buffer (Phase 9 acceptance review R2); and typeahead has
  -- no way to report "nothing was sent".
  local region = require('mini.ai').find_textobject('i', 'h')
  if region then
    local lines = vim.api.nvim_buf_get_lines(0, region.from.line - 1, region.to.line, false)
    require('iron.core').send(vim.bo.filetype, lines)
  end
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
  -- Measured, three messages held: `<Esc>` leaves `:Noice`/`<leader>n` at 3.
  pcall(function()
    require('noice').cmd('dismiss')
  end)
end

return M
