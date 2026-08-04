-- Sessions.
--
-- Phase 5 kept auto-session rather than moving to `mini.sessions` (which the
-- plan file proposed, and which would have meant porting these hooks verbatim
-- for no gain) and modernised it in place instead: the `session-lens`
-- dependency is gone - upstream deprecated it and folded it into auto-session's
-- own `:SessionSearch`, which detects a picker backend by itself - and the
-- option names below are the current ones rather than the pre-2.0 spellings
-- that the compatibility table in `auto-session/config.lua` was translating
-- (and that `:checkhealth auto-session` was nagging about).
--
-- The hooks are what is *left* after checking each one against what
-- auto-session already does by itself. `close_unsupported_windows` defaults to
-- true, so it has been running all along underneath the old hook: it closes
-- every window whose buffer is not a readable file and is not a terminal,
-- which covers the drawer/tool/float sweep `close_aux_windows` used to do by
-- hand.

local A = vim.api

-- allow at most one unnamed, unmodified buffer, closing all others
--
-- No auto-session equivalent: `auto_delete_empty_sessions` deletes the whole
-- *session* when only blank buffers are left, and `preserve_buffer_on_restore`
-- filters its restore-time wipeout. Neither consolidates.
local function consolidate_unnamed()
  local consolidated = nil
  -- for any buf displayed in window, set to the first buf we encountered
  for _, win in pairs(A.nvim_list_wins()) do
    local buf = A.nvim_win_get_buf(win)
    if A.nvim_buf_get_name(buf) == '' and not vim.bo[buf].modified then
      if not consolidated then
        consolidated = buf
      end
      if buf ~= consolidated then
        A.nvim_win_set_buf(win, consolidated)
        A.nvim_buf_delete(buf, {})
      end
    end
  end

  -- for other remaining bufs, deleted them
  for _, buf in pairs(A.nvim_list_bufs()) do
    if A.nvim_buf_get_name(buf) == '' and not vim.bo[buf].modified and buf ~= consolidated then
      A.nvim_buf_delete(buf, {})
    end
  end
end

-- Close the windows a session should not record.
--
-- This cannot delegate to auto-session's `close_unsupported_windows`, even
-- though that option is on. Measured: it is called from
-- `AutoSession.auto_save_session()` only (`auto-session/init.lua:339`), i.e. on
-- the `VimLeavePre` autosave path - `save_session()`, which is what
-- `:AutoSession save` and `<leader>sc` reach, never calls it. Dropping this
-- sweep on the strength of the option being enabled restored a stale neo-tree
-- drawer into the layout after a manual save/restore cycle (5 windows instead
-- of 4), which is how that was found.
--
-- The *rule* is borrowed from upstream rather than the old filetype list
-- (`fern`/`Trouble`/`*tree*`/`Neogit`): a window is unsupported if its buffer
-- is not backed by a readable file and is not a terminal. That covers drawers,
-- tool windows and floating notification toasts without needing a list of
-- plugin filetypes to keep up to date.
--
-- Two things upstream's rule does not cover, and this does:
--   * diffview - closing the window would leave diffview's own view registry
--     pointing at it, so the view has to be taken down through its API first.
--   * help - a help buffer *is* backed by a readable file, so upstream
--     deliberately leaves it open; a restored session turns it into an empty
--     split.
local function unsupported_window(win)
  local buf = A.nvim_win_get_buf(win)
  local buftype = vim.bo[buf].buftype
  if buftype == 'help' then
    return true
  end
  return buftype ~= 'terminal' and vim.fn.filereadable(A.nvim_buf_get_name(buf)) == 0
end

local function close_aux_windows()
  local has_diffview, diffview_lib = pcall(require, 'diffview.lib')
  if has_diffview then
    for _, tab in pairs(A.nvim_list_tabpages()) do
      local view = diffview_lib.tabpage_to_view(tab)
      if view then
        view:close()
        diffview_lib.dispose_view(view)
      end
    end
  end

  for _, win in pairs(A.nvim_list_wins()) do
    -- never close the last window of the last tab, as upstream does not either
    if vim.fn.tabpagenr('$') == 1 and vim.fn.winnr('$') == 1 then
      return
    end
    if A.nvim_win_is_valid(win) and unsupported_window(win) then
      A.nvim_win_close(win, true)
    end
  end
end

return {
  'rmagatti/auto-session',
  cond = require('ucw.targets').is_full_ui,
  config = function()
    require('auto-session').setup {
      log_level = 'warn',
      auto_restore = false,
      suppressed_dirs = { '~/', '/dev/shm', '/tmp' },
      pre_save_cmds = {
        close_aux_windows,
        consolidate_unnamed,
      },
      -- `restore_shortmess` (`set shortmess&`) used to run here, on the grounds
      -- that "sometimes session messes with shortmess". It did the opposite of
      -- restoring: `&` resets to Neovim's factory default, discarding
      -- `lua/ucw/options.lua`'s `shortmess:append('s')` on every single
      -- restore. Measured before removing it - `tOFToslC` before a restore,
      -- `ltToOCF` (no `s`) after. The session file already brackets its own
      -- `set shortmess+=aoO` with a save/restore pair, so there was never
      -- anything for the hook to fix in the first place.
      post_restore_cmds = {
        consolidate_unnamed,
      },
      bypass_save_filetypes = { 'neotree', 'help' },
      -- Don't define the legacy `:Session*` / `:Autosession` commands. They
      -- still work but notify a deprecation warning when used, and leaving them
      -- defined is how `<leader>ss` went on invoking `:SessionSearch` - the
      -- same shape of staleness as the old option names above, one layer down.
      legacy_cmds = false,
    }
  end,
}
