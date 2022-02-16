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
  local U = require('Comment.utils')

  -- Detemine whether to use linewise or blockwise commentstring
  local type = ctx.ctype == U.ctype.line and '__default' or '__multiline'

  -- Determine the location where to calculate commentstring from
  local location = nil
  if ctx.ctype == U.ctype.block then
      location = require('ts_context_commentstring.utils').get_cursor_location()
  elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
      location = require('ts_context_commentstring.utils').get_visual_start_location()
  end

  return require('ts_context_commentstring.internal').calculate_commentstring({
      key = type,
      location = location,
  })
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
