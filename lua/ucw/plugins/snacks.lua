-- snacks.nvim owns three things here: `vim.ui.input`, the fuzzy picker
-- (`vim.ui.select` and every explicit picker keybinding), and `vim.notify`
-- rendering.
--
-- Phase 5 made the picker part load-bearing. Before it, `picker.ui_select`
-- was already routing every `vim.ui.select` through snacks while Telescope
-- owned the keybindings - two fuzzy pickers, both loaded at every startup.
-- Telescope is gone; this is the only one left.
--
-- The notifier is *not* what `vim.notify` points at: noice is (it wraps
-- `vim.notify` in `noice/source/notify.lua`), and noice's `notify` view
-- renders through this notifier. See `noice.lua`.

local utils = require('ucw.utils')

-- Telescope bound `<c-d>` in its buffers picker to a delete that goes through
-- `ucw.utils.bufdelete` rather than `:bdelete`, so that closing a buffer
-- leaves the window layout alone and lands the window on the previous *normal*
-- buffer from its jumplist. snacks has its own `bufdelete` action; it calls
-- `Snacks.bufdelete`, which has no jumplist preference. Shape copied from
-- `snacks/picker/actions.lua:338` so multi-select and the list refresh behave
-- the same.
local function bufdelete(picker)
  picker.preview:reset()
  for _, item in ipairs(picker:selected({ fallback = true })) do
    if item.buf then
      utils.bufdelete(item.buf)
    end
  end
  picker:refresh()
end

local function config()
  require('snacks').setup {
    input = { enabled = true },

    notifier = {
      enabled = true,
      -- `compact` puts the icon and title inline in the top border (3 lines per
      -- notification); `fancy` is the nvim-notify shape this replaced (4 lines,
      -- separate title row and rule). Chosen by looking at all three styles
      -- rendered under this config's own colorscheme, not from the docs.
      style = 'compact',
      -- Carried over verbatim from the nvim-notify config so that the size
      -- does not change under us at the same time as the renderer.
      timeout = 3000,
      width = { min = 30, max = 55 },
    },

    picker = {
      ui_select = true,
      win = {
        input = {
          keys = {
            -- Close from insert mode too. snacks' default `<Esc>` is normal
            -- mode only, i.e. it drops the prompt into normal mode first;
            -- Telescope's config bound `<esc>` straight to close and that is
            -- the muscle memory being preserved. `cancel` rather than `close`
            -- because it also puts the cursor back in the window the picker
            -- was opened from.
            ['<Esc>'] = { 'cancel', mode = { 'n', 'i' } },
          },
          wo = {
            -- GUI-only: Telescope had `winblend = is_gui() and 10 or 0`, and 0
            -- is snacks' default anyway, so this only ever does anything under
            -- neovide/nvui - neither of which is installed here, so it is
            -- carried over rather than verified.
            winblend = utils.is_gui() and 10 or 0,
          },
        },
      },
      sources = {
        buffers = {
          -- Telescope had `previewer = false` here: the file is already open,
          -- there is nothing to preview that the buffer list does not say.
          preview = false,
          actions = { ucw_bufdelete = bufdelete },
          win = {
            input = {
              keys = {
                -- Shadows snacks' `list_scroll_down` in this picker only,
                -- which is what Telescope's binding did too.
                ['<c-d>'] = { 'ucw_bufdelete', mode = { 'n', 'i' } },
              },
            },
          },
        },
      },
    },
  }
end

return {
  'folke/snacks.nvim',
  lazy = false,
  dependencies = { 'echasnovski/mini.nvim' },
  config = config,
}
