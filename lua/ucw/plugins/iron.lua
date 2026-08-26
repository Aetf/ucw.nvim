-- On a machine without the REPL binary, every REPL key used to throw
-- E475 with a full lua traceback, once per keypress (measured in the kpxc
-- distrobox: no ipython; iron errors inside `ll.create` where nothing
-- catches it). iron cannot degrade by itself here because this config
-- pins `repl_definition.python = ipython` - an explicit definition wins
-- over iron's own first-executable-binary provider scan, executable or
-- not. So the guard resolves the definition exactly the way iron will
-- (`ll.get_repl_def`) and probes the binary up front: warn once per
-- filetype per session, swallow the press otherwise. The probe re-runs on
-- every press (it is one `executable()` call), so installing the binary
-- mid-session brings the keys back without a restart - only the warning
-- is once-per-session.
local repl_warned = {}
local function repl_ready()
  local ft = vim.bo.filetype
  local ok, def = pcall(function()
    return require('iron.lowlevel').get_repl_def(ft)
  end)
  if not ok or not def then
    if not repl_warned[ft] then
      repl_warned[ft] = true
      vim.notify(
        ('iron: no usable REPL for filetype %q (no definition, or no binary on PATH)'):format(ft),
        vim.log.levels.WARN
      )
    end
    return false
  end
  local cmd = def.command
  local exe = (type(cmd) == 'table' and cmd[1]) or (type(cmd) == 'string' and cmd) or nil
  -- a function-valued command cannot be probed without running it; let
  -- iron take its chances
  if exe and vim.fn.executable(exe) == 0 then
    if not repl_warned[ft] then
      repl_warned[ft] = true
      vim.notify(
        ('iron: %q is not executable; REPL keys for %s do nothing until it is installed'):format(exe, ft),
        vim.log.levels.WARN
      )
    end
    return false
  end
  return true
end

-- rhs wrapper: press does nothing (after the one warning) when no REPL
-- can possibly start
local function repl_key(fn)
  return function()
    if repl_ready() then
      fn()
    end
  end
end

return {
  'hkupty/iron.nvim',
  -- `keys` alone would flip the spec to lazy-loading; iron owns REPL windows
  -- from startup, so stay eager (Phase 8 relocates registration, not
  -- triggers).
  lazy = false,
  -- `<leader>r` = REPL (Phase 9, D5; the tree lived on `<leader>e`, freed
  -- for the explorer). These are bound here rather than through iron's
  -- `keymaps =` table: iron hardcodes identifier-style descs
  -- (`iron_repl_send_file`, core.lua:832) with no way to override, and every
  -- rhs in its `named_maps` is a thin wrapper over the public API anyway -
  -- so the spec binds the same entry points with prose descriptions (Phase 8
  -- handoff R5b). `rs` is mode-symmetric on purpose: motion in normal,
  -- selection in visual - one key, one meaning.
  keys = {
    -- there was no "open the REPL" key at all before Phase 9
    {
      '<leader>rr',
      repl_key(function()
        vim.cmd('IronRepl')
      end),
      desc = 'Toggle the REPL window',
      silent = true,
    },
    {
      '<leader>rs',
      repl_key(function()
        require('iron.core').run_motion('send_motion')
      end),
      desc = 'Send a motion to the REPL',
      silent = true,
    },
    {
      '<leader>rs',
      repl_key(function()
        require('iron.core').visual_send()
      end),
      desc = 'Send the selection to the REPL',
      mode = 'v',
      silent = true,
    },
    {
      '<leader>rl',
      repl_key(function()
        require('iron.core').send_line()
      end),
      desc = 'Send the current line to the REPL',
      silent = true,
    },
    {
      '<leader>rf',
      repl_key(function()
        require('iron.core').send_file()
      end),
      desc = 'Send the whole file to the REPL',
      silent = true,
    },
    {
      '<leader>r<CR>',
      repl_key(function()
        require('iron.core').send(nil, string.char(13))
      end),
      desc = 'Send a return to the REPL',
      silent = true,
    },
    {
      '<leader>rc',
      repl_key(function()
        require('iron.core').send(nil, string.char(3))
      end),
      desc = 'Interrupt the REPL',
      silent = true,
    },
    {
      '<leader>rx',
      repl_key(function()
        require('iron.core').send(nil, string.char(12))
      end),
      desc = 'Clear the REPL screen',
      silent = true,
    },
    {
      '<leader>rq',
      repl_key(function()
        require('iron.core').close_repl()
      end),
      desc = 'Exit the REPL',
      silent = true,
    },
    {
      '<C-Enter>',
      "<cmd>lua require('ucw.keys.actions').iron_send_block()<cr>",
      desc = 'Send block to REPL',
      mode = { 'n', 'v', 'i' },
      silent = true,
    },
    {
      '<S-Enter>',
      "<cmd>lua require('ucw.keys.actions').iron_send_block({next=true})<cr>",
      desc = 'Send block to REPL and move to next',
      mode = { 'n', 'v', 'i' },
      silent = true,
    },
  },
  init = function()
    -- we define our own mapping
    vim.g.iron_map_defaults = 0
    vim.g.iron_map_extended = 0
  end,
  config = function()
    local iron = require('iron.core')

    iron.setup {
      config = {
        scratch_repl = false,
        highlight_last = false,
        should_map_plug = false,
        repl_definition = {
          python = require('iron.fts.python').ipython,
        },
        repl_open_cmd = 'vsplit',
      },
      -- no `keymaps =`: see the spec's `keys` above
    }
  end,
}
