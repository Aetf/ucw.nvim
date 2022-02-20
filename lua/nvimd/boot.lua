local cmd = vim.cmd
local F = vim.fn

local M = {}

function M.paq()
  local present, paq = pcall(require, 'paq')
  if not present then
    local install_path = F.stdpath('data')..'/site/pack/paqs/start/paq-nvim'
    F.system({'git', 'clone', '--depth', '1', 'https://github.com/savq/paq-nvim', install_path})
    -- when bootstraping, we have to manually add it to runtimepath
    cmd [[packadd paq-nvim]]
    return require('paq')
  else
    return paq
  end
end

return M
