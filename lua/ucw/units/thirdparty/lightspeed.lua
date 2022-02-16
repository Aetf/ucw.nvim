local M = {}

M.url = 'ggandor/lightspeed.nvim'
M.description = 'Fast movement using 2-char search and enhanced f'

M.wants = {
  'vim-repeat',
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

-- configs

local map = require('ucw.utils').map

function M.config()
  -- use bidirection s
  map('n', 's', '<Plug>Lightspeed_omni_s', { remap = false })
end


return M
