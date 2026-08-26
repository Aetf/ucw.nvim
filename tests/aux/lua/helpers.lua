local M = {}
local H = {}

function H.chain_after(hook, fn, ...)
  local arg = { ... }
  return function()
    if hook then
      hook()
    end
    fn(unpack(arg))
  end
end

function H.chain_before(hook, fn, ...)
  local arg = { ... }
  return function()
    fn(unpack(arg))
    if hook then
      hook()
    end
  end
end

function H.mini_test_rtp()
  local search_all = false
  local paths = vim.api.nvim_get_runtime_file('lua/mini/test.lua', search_all)
  if not paths then
    error('No mini.test found!')
  end
  return paths[1]:gsub('lua/mini/test%.lua$', '')
end

-- With the full config booted (lazy.nvim + all plugins)
function M.new_integration_test(opts)
  local child = MiniTest.new_child_neovim()
  local state = {
    tempdir = vim.fn.tempname(),
  }

  opts = opts or {}
  opts.hooks = opts.hooks or {}
  opts.hooks = {
    pre_once = H.chain_before(opts.hooks.pre_once, function()
      vim.fn.mkdir(state.tempdir, 'p')
    end),

    pre_case = H.chain_before(opts.hooks.pre_case, function()
      child.restart {}

      -- use a temporary directory as the packpath,
      -- such that automatic plugin installation can be tested
      child.env.XDG_DATA_HOME = state.tempdir .. '/data/site'
      child.o.rtp = child.env.XDG_DATA_HOME .. ',' .. child.o.rtp
      child.o.packpath = child.env.XDG_DATA_HOME .. ',' .. child.o.packpath

      -- make sure current directory (repo top-level) is in runtime path
      child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp

      -- boot the full config, then set up mini.test on top (mini.nvim
      -- is already a plugin the config installs, via lua/ucw/plugins/mini.lua)
      child.lua([[require('ucw').boot()]])
      -- lazy.nvim's own bootstrap-install runs async; block until it
      -- actually settles so the "full config booted" the test assumes
      -- is genuinely fully installed, not mid-install (avoids flaky
      -- screenshot/UI assertions racing lazy's install pipeline)
      child.lua([[require('lazy.manage').install()]])
      child.lua([[require('mini.test').setup()]])

      -- Booting the full config prints more than fits the child's
      -- 24-line screen (treesitter warning, plugin install notices, ...),
      -- which leaves Neovim sitting at a hit-enter prompt. Nothing is
      -- drawn for it, but it silently swallows the first keystrokes a
      -- test sends, so any typing-based test appears to do nothing at
      -- all. Dismiss it, then confirm we really are back in normal mode
      -- rather than assuming the <CR> was enough.
      child.lua([[
                if vim.api.nvim_get_mode().mode ~= 'n' then
                  vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)
                end
            ]])
      local mode = child.lua_get([[vim.api.nvim_get_mode().mode]])
      if mode ~= 'n' then
        error(('child stuck in mode %q after boot; a prompt is still pending'):format(mode))
      end

      -- Separately: the first `nvim_feedkeys` batch sent after that
      -- prompt is cleared gets truncated - only its first key survives,
      -- the rest is dropped. Measured, not guessed: feeding "icopyri" as
      -- the first batch lands in insert mode with an empty line, while
      -- the identical call as the second batch types the whole word.
      -- Burn that first batch here on a pair of harmless <Esc>s so tests
      -- get a child that types the keys they actually asked for.
      child.lua([[vim.api.nvim_feedkeys('\27\27', 'nt', false)]])
      child.api.nvim_eval('1')
    end, child),

    post_case = opts.hooks.post_case,

    post_once = H.chain_after(opts.hooks.post_once, function()
      -- stop once all test cases are finished
      child.stop()
      vim.fn.delete(state.tempdir, 'rf')
    end, child),
  }

  opts.data = opts.data or {}
  opts.data.tags = opts.data.tags or {}
  table.insert(opts.data.tags, 'integration')

  local T = MiniTest.new_set(opts)
  return T, child
end

-- Reboot an integration-test `child` into one of the embedded contexts
-- (`marker` is 'vscode' or 'started_by_firenvim').
--
-- The marker has to be set *before* `ucw.boot()` and that is the whole reason
-- this exists: lazy.nvim evaluates every spec's `cond` while `init.lua` is
-- still sourcing, and the standard `pre_case` hook has already booted the
-- full-UI config by the time a test body runs, so there is nothing left to
-- flip afterwards. Reuses the already-populated XDG_DATA_HOME, so the reboot
-- costs a boot rather than a download.
function M.boot_embedded(child, marker)
  local xdg = child.env.XDG_DATA_HOME
  child.restart {}
  child.env.XDG_DATA_HOME = xdg
  child.o.rtp = xdg .. ',' .. child.o.rtp
  child.o.packpath = xdg .. ',' .. child.o.packpath
  child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp
  child.g[marker] = true
  child.lua([[require('ucw').boot()]])
  child.lua([[require('lazy.manage').install()]])
  if child.lua_get([[require('ucw.targets').is_full_ui()]]) ~= false then
    error(('child booted with g:%s is still a full-UI target'):format(marker))
  end
end

-- Without booting the full config
function M.new_unit_test(opts)
  local child = MiniTest.new_child_neovim()

  opts = opts or {}
  opts.hooks = opts.hooks or {}
  opts.hooks = {
    pre_once = opts.hooks.pre_once,

    pre_case = H.chain_before(opts.hooks.pre_case, function()
      child.restart {}

      -- make sure current directory (repo top-level) is in runtime path
      child.o.rtp = vim.fn.getcwd() .. ',' .. child.o.rtp

      child.o.rtp = child.o.rtp .. ',' .. H.mini_test_rtp()
      child.lua([[require('mini.test').setup({})]])
    end, child),

    post_case = opts.hooks.post_case,

    post_once = H.chain_after(opts.hooks.post_once, function()
      -- stop once all test cases are finished
      child.stop()
    end, child),
  }

  opts.data = opts.data or {}
  opts.data.tags = opts.data.tags or {}
  table.insert(opts.data.tags, 'unit')

  local T = MiniTest.new_set(opts)
  return T, child
end

return M
