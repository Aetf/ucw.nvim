local map = require('ucw.utils').map
local is_gui = require('ucw.utils').is_gui

local function pre_hook(ctx)
  return require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook()(ctx)
end

return {
  'numToStr/Comment.nvim',
  lazy = false,
  dependencies = {
    {
      'JoosepAlviste/nvim-ts-context-commentstring',
      config = function()
        vim.g.skip_ts_context_commentstring_module = true
        require('ts_context_commentstring').setup {}
      end,
    },
  },
  config = function()
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
  end,
}
