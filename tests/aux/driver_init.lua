-- This is the init file for the test driver, since all test cases are run in
-- subprocess, the driver init intentionally does nothing and load no
-- dependencies.

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() ~= 0 then
  error('Test driver init.lua called from non-headless nvim instance')
end

-- Locate mini.nvim from already installed pack
local paths = vim.api.nvim_get_runtime_file('pack/*/opt/mini/', false)
if #paths > 0 then
  vim.opt.rtp:append{ paths[1] }
else
  -- no already installed mini.nvim
  -- assume it's already installed in CI
  vim.opt.rtp:append{ vim.fn.getcwd() .. '/deps/mini.nvim' }
end

-- Locate test helper rtp
vim.opt.rtp:append{ vim.fn.getcwd() .. '/tests/aux' }


-- Set up 'mini.test'
require('mini.test').setup()

