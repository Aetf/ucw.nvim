local M = {}

M.url = 'numToStr/Comment.nvim'
M.description = 'Commenting actions'

M.wants = {
  'ts-context-commentstring'
}

-- ways to activate this
M.activation = {
  wanted_by = {
    'target.basic'
  }
}

-- configs

local map = require('ucw.utils').map
local is_gui = require('ucw.utils').is_gui

local function pre_hook(ctx)
  return require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()(ctx)
end

function M.config()
  require('Comment').setup {
    ignore = '^$', -- ignore empty lines when commenting
    pre_hook = pre_hook,
  }
  -- one additional keymap for easy line comment
  if is_gui() then
    map('n', '<c-/>', 'gcc', { noremap = false })
  else
    -- this is actually Ctrl + /, but in terminal, nvim sees as <c-_>
    map('n', '<c-_>', 'gcc', { noremap = false })
  end
end


return M
