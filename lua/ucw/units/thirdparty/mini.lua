local M = {}

M.url = 'echasnovski/mini.nvim'
M.description = 'Library of 20+ independent Lua modules improving overall Neovim (version 0.6 and higher) experience with minimal effort'

M.wants = {
}

-- other mini library will drag in this
M.activation = {
}

function M.setup()
  -- latex command, similar to function
  --[[ vim.g['surround_' .. vim.fn.char2nr('c')] = "\\\1command\1{\r}" ]]
end

return M
