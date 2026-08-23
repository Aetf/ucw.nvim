-- The seam between neogit (which knows what commit the cursor is on) and
-- codediff (which knows how to render a diff), plus the one thing neither of
-- them shows: the commit message.
--
-- It lives outside both plugin specs because both ends need it. `neogit.lua`
-- rebinds `<CR>` through `commit_under_cursor`/`open_diff`; `codediff.lua`
-- binds `<leader>gm` to `show_message`, which resolves its revision from a
-- neogit buffer *or* from a codediff tab depending on where it is pressed.

local M = {}

---The commit the cursor is on, in whichever neogit buffer we are in, or nil
---when the cursor is not on a commit (which includes every non-neogit buffer).
---
---The status buffer needs the same test neogit's own `n_goto_file` makes
---(`buffers/status/actions.lua`): a row that carries a file path is a file,
---and only a row that carries none is a commit. Without it, `<CR>` on a
---changed file would stop opening the file - the status buffer's other rows
---must keep working exactly as they do.
---@return string|nil ref a commit-ish neogit would accept (an oid, or a stash ref)
function M.commit_under_cursor()
  local ft = vim.bo.filetype

  if ft == 'NeogitLogView' then
    local ok, log_view = pcall(require, 'neogit.buffers.log_view')
    if not ok or not log_view.instance then
      return nil
    end
    return log_view.instance.buffer.ui:get_commit_under_cursor()
  end

  if ft == 'NeogitStatus' then
    local ok, status = pcall(require, 'neogit.buffers.status')
    if not ok then
      return nil
    end
    local instance = status.instance()
    if not instance then
      return nil
    end

    local ui = instance.buffer.ui
    local item = ui:get_item_under_cursor()
    if item and item.absolute_path then
      return nil
    end

    -- Every commit-shaped row in the status UI carries the oid as its
    -- `yankable` (`buffers/status/ui.lua`): recent commits, unmerged and
    -- unpulled entries, stashes, and the `Head:`/`Merge:`/`Push:` lines at
    -- the top. Files carry their name there instead, which is what the
    -- `absolute_path` test above has already taken out.
    return ui:get_yankable_under_cursor()
  end

  return nil
end

---Open `ref^..ref` in codediff, the same view `dd` reaches through neogit's
---diff popup.
---
---Through the `commit` section rather than `log`: codediff's neogit
---integration resolves a `commit` through `git rev-parse`, so it takes any
---commit-ish (a stash ref, a branch name on the `Head:` line), while the
---`log` path only pattern-matches a hex oid out of the string.
---@param ref string
function M.open_diff(ref)
  require('neogit.integrations.codediff').open('commit', ref)
end

---The revision a codediff tab is showing, or nil if this tab is not one.
---@return string|nil rev, string|nil git_root
local function codediff_revision()
  local ok, session = pcall(require, 'codediff.ui.lifecycle.session')
  if not ok or type(session.get_active_diffs) ~= 'function' then
    return nil, nil
  end

  local diff = session.get_active_diffs()[vim.api.nvim_get_current_tabpage()]
  if not diff or type(diff.modified_revision) ~= 'string' or diff.modified_revision == '' then
    return nil, nil
  end

  return diff.modified_revision, diff.git_root
end

---`<leader>gm`: the commit message for whatever is on screen.
---
---codediff renders a diff and nothing else - no subject, no body, not even
---which commit it is - and neogit's own commit view, the one place that shows
---the message, is what `<CR>` stopped opening. This is that half, in a form
---that does not need a window of its own: press it in a neogit buffer for the
---commit under the cursor, or anywhere in a codediff tab for the commit that
---tab is diffing.
function M.show_message()
  local ref = M.commit_under_cursor()
  local root

  if not ref then
    ref, root = codediff_revision()
  end

  if not ref then
    vim.notify('No commit here (open a codediff tab or a neogit buffer)', vim.log.levels.WARN)
    return
  end

  local cmd = { 'git' }
  if root then
    vim.list_extend(cmd, { '-C', root })
  end
  -- `fuller` is what neogit's own commit view shows: author and committer
  -- both, which differ on anything that has been rebased or cherry-picked.
  vim.list_extend(cmd, { 'show', '--no-patch', '--format=fuller', ref })

  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify(('git show failed for %s: %s'):format(ref, vim.trim(result.stderr or '')), vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(vim.trim(result.stdout or ''), '\n', { plain = true })

  -- `q` closes it: `Snacks.win`'s own default, and the same key every other
  -- read-only window in this config uses (see `ucw.extras`).
  Snacks.win {
    text = lines,
    -- `bo.filetype`, not the `ft` option: `ft` is documented as "won't
    -- override existing filetype", and snacks has already stamped its scratch
    -- buffer `snacks_win` by then - measured, the float rendered unhighlighted.
    bo = { filetype = 'git' },
    enter = true,
    title = (' %s '):format(ref:sub(1, 8)),
    title_pos = 'center',
    border = 'rounded',
    width = 0.7,
    height = 0.6,
    wo = { wrap = true, linebreak = true, number = false, signcolumn = 'no' },
  }
end

return M
