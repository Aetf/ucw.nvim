--[[
Packages managed by packer.nvim in compiled lazy loading mode to optimize startup time.
Basically, there is no need to load `packer.nvim` unless to perform some plugin management operations.
Instead, a compiled file `compiled.lua` is generated and we'll require it explicitly on startup.

When initializing packer.nvim, we disable its default command registration.
Then in the main `init.lua` file, we define `Packer*` commands to call the init function defined here
before its normal operation.
--]]
local F = vim.fn
local pu = require('ucw.plugins.utils')

local M = {}


M.action = function(action, reload)
    -- default reload to true
    if reload == nil then
        reload = true
    end

    if reload then
        require('plenary.reload').reload_module('ucw.plugins.specs')
    end
    local packer = pu.get_packer()
    require('ucw.plugins.specs').apply(packer)

    packer[action]()
end

M.register_commands = function()
  -- XXX: move to lua api (vim.api.nvim_add_user_command) once neovim 0.7 is relased
  vim.cmd [[command! PackerInstall lua require('ucw.plugins').action('install')]]
  vim.cmd [[command! PackerUpdate lua require('ucw.plugins').action('update')]]
  vim.cmd [[command! PackerSync lua require('ucw.plugins').action('sync')]]
  vim.cmd [[command! PackerClean lua require('ucw.plugins').action('clean')]]
  vim.cmd [[command! PackerCompile lua require('ucw.plugins').action('compile')]]
end

M.maybe_sync = function()
  -- no compiled plugin list, probaly the first install
  if F.filereadable(pu.compile_path) == 0 then
    -- just do a full sync with reload = false
    M.action('sync', false)
    return true
  end
  return false
end

function M.setup()
  M.register_commands()
  local first_install = M.maybe_sync()
  if not first_install then
    require('ucw.plugins.compiled')
  end

  -- Most of our plugins are in opt, so the compiled file only setup paths
end

function M.load(plugin)
  local packer = pu.get_packer()
  return packer.loader(plugin)
end

return M
