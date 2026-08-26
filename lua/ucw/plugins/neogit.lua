-- `<CR>` on a commit opens codediff instead of neogit's own commit view
-- (Phase 9.5, T7). The commit view renders the message well and the diff
-- poorly - one inline unified hunk list, no file tree, no side-by-side, none
-- of the character-level highlighting codediff's engine produces - and `dd`
-- already reached codediff through the diff popup. `<CR>` is the key the hand
-- goes to; this makes it the same door. The message the commit view was the
-- only source of is `<leader>gm` now (`ucw.git.show_message`).
local ENTER_DESC = 'Diff this commit (codediff)'

-- Why a buffer-local override and not `mappings`: neogit has no `log_view`
-- mapping table. The log view binds its own functions onto whatever lhs
-- `mappings.status` gave the *action names* (`[status_maps["GoToFile"]] =
-- function() ... end`, `buffers/log_view/init.lua`), so moving `<cr>` in the
-- config would move it in the status buffer too, where it means "open the
-- file under the cursor" and must keep meaning that.
--
-- `BufWinEnter`, not `FileType`: `lib/buffer.lua` sets the filetype (:766),
-- *then* the mappings (:785), then shows the window (:807). A `FileType`
-- callback therefore runs before neogit's own mapping exists and is
-- overwritten by it - measured, the override simply had no effect. This is
-- not a delay standing in for an event; it is the first event upstream
-- guarantees is after the thing being overridden.
local function setup_enter_override()
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = vim.api.nvim_create_augroup('ucw_neogit_enter', { clear = true }),
    desc = 'Route <CR> on a commit to codediff',
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      if ft ~= 'NeogitLogView' and ft ~= 'NeogitStatus' then
        return
      end

      local existing = vim.fn.maparg('<CR>', 'n', false, true)
      -- Already wrapped: `BufWinEnter` fires again every time the buffer is
      -- shown, and re-reading `maparg` there would capture *this* wrapper as
      -- its own fallback. When neogit re-creates the buffer it re-applies its
      -- mapping, the desc stops matching, and the wrap happens again.
      if existing.desc == ENTER_DESC then
        return
      end

      local fallback = existing.callback
      if type(fallback) ~= 'function' then
        -- Nothing to delegate to means every non-commit row would go dead.
        -- Leave neogit's key alone and say why, rather than half-work.
        vim.notify('ucw: neogit bound no <CR> callback; leaving it alone', vim.log.levels.WARN)
        return
      end

      vim.keymap.set('n', '<CR>', function()
        local ref = require('ucw.git').commit_under_cursor()
        if ref then
          require('ucw.git').open_diff(ref)
        else
          fallback()
        end
      end, { buffer = ev.buf, desc = ENTER_DESC, silent = true })
    end,
  })
end

return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`. The plugin was
  -- already lazy on `cmd`; the key now also lazy-load-triggers it, so at boot
  -- the mapping is lazy.nvim's stub (callback) rather than the raw string.
  keys = {
    { '<leader>gg', '<cmd>Neogit<cr>', desc = 'Neogit', silent = true },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- the diff viewer neogit hands off to; see lua/ucw/plugins/codediff.lua
    -- for why it is codediff and not diffview.
    'esmuellert/codediff.nvim',
  },
  config = function()
    local neogit = require('neogit')

    setup_enter_override()

    neogit.setup {
      -- then this will use vim.nofity, which will use our fancy floating notification system
      disable_builtin_notifications = true,
      disable_commit_confirmation = true,
      integrations = {
        codediff = true,
      },
      -- neogit auto-detects diffview first and only then codediff; be explicit
      -- so the choice does not depend on what else happens to be installed.
      diff_viewer = 'codediff',
      mappings = {
        -- for the status buffer
        status = {
          ['<ESC>'] = 'Close',
        },
      },
    }
  end,
}
