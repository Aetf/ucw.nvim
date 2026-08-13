-- This is the init file for the test driver, since all test cases are run in
-- subprocess, the driver init intentionally does nothing and load no
-- dependencies.

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() ~= 0 then
  error('Test driver init.lua called from non-headless nvim instance')
end

-- Test-only clone of mini.nvim, fetched via `just deps`. This is dedicated
-- to running the test suite itself (mini.test) and is intentionally separate
-- from the runtime mini.nvim plugin that lazy.nvim installs/manages on its
-- own for actual editing features (see lua/ucw/plugins/mini.lua) - the two
-- are not meant to share a copy.
-- `rtp:append` is annotated as taking a string; it takes a table too (that is
-- how `vim.opt` list options work), which is the form this file has always
-- used. Same on the next append.
---@diagnostic disable-next-line: param-type-mismatch
vim.opt.rtp:append { vim.fn.getcwd() .. '/deps/mini.nvim' }

-- Locate test helper rtp
---@diagnostic disable-next-line: param-type-mismatch
vim.opt.rtp:append { vim.fn.getcwd() .. '/tests/aux' }

-- Set up 'mini.test'
require('mini.test').setup()
