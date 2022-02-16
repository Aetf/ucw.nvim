local F = vim.fn
local cmd = vim.cmd

local M = {}

M.compile_path = F.stdpath('data') .. '/site/lua/ucw/plugins/compiled.lua'

-- packer.nvim bootstrap
local _packer = nil
function M.get_packer()
  if _packer == nil then
    local ok, res = pcall(require, 'packer')
    if not ok then
      -- install packer.nvim
      local install_path = F.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
      F.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
      -- when bootstraping, we have to manually add it to runtimepath
      -- can not use packadd here, as the path seems to be built during startup and at this stage vim can't find it
      cmd [[packadd packer.nvim]]
      --vim.opt.runtimepath:append(install_path)
      _packer = require 'packer'
    else
      _packer = res
    end
    -- initialize packer
    _packer.init {
      compile_path = M.compile_path,
      disable_commands = true,
      opt_default = true,
      display = {
	open_fn = function() return require('packer.util').float({ border = 'single' }) end,
	prompt_border = 'single',
      }
    }
  end
  -- always reset for a fresh instance
  _packer.reset()
  -- Packer can manage itself
  _packer.use {
    'wbthomason/packer.nvim',
  }

  return _packer
end

-- create a dummy use spec that can be used to group load plugins later
function M.target(name, deps)
  local async = require('packer.async').sync
  local result = require('packer.result')
  return use {
    name,
    installer = function(_) return async(function() return result.ok() end) end,
    updater = function(_) return async(function() return result.ok() end) end,
    wants = deps,
  }
end

return M
