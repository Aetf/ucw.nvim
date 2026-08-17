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
  for _, item in ipairs(picker:selected { fallback = true }) do
    if item.buf then
      utils.bufdelete(item.buf)
    end
  end
  picker:refresh()
end

local function config()
  local winblend = utils.is_gui() and 10 or 0

  require('snacks').setup {
    input = { enabled = true },

    -- Automatic LSP reference highlighting (Phase 9, D2): replaces the manual
    -- `<leader>lh` / `<leader>l<C-L>` pair - highlights update on cursor
    -- movement (debounced) and clear by themselves. Highlight only: snacks
    -- does not bind its `jump` function to anything by itself, and the
    -- conventional `]]`/`[[` bindings would shadow the native section
    -- motions (design doc §2.2, r2.1), so no jump keys are bound here.
    words = { enabled = true },

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
          -- GUI-only: Telescope had `defaults.winblend = is_gui() and 10 or 0`,
          -- which applied to its whole picker, and 0 is snacks' default anyway.
          -- So this only ever does anything under neovide/nvui - neither of
          -- which is installed here, hence carried over rather than verified.
          -- All three windows, because Telescope's was not per-window (the
          -- Phase 5 acceptance review's R6 was this set on `input` alone).
          wo = { winblend = winblend },
        },
        list = { wo = { winblend = winblend } },
        preview = { wo = { winblend = winblend } },
      },
      sources = {
        buffers = {
          -- Telescope had `previewer = false` here: the file is already open,
          -- there is nothing to preview that the buffer list does not say.
          --
          -- It has to be spelled as a *layout* option. A source-level
          -- `preview = false` is silently discarded - that field is typed
          -- "previewer function or preset name", and the resolver is
          -- `opts.preview or Snacks.picker.preview.file`
          -- (`snacks/picker/config/init.lua:198`), so `false` falls straight
          -- through to the default file previewer. `layout.preview = false` is
          -- the switch, and becomes `layout.hidden = { 'preview' }`.
          -- Typed `"main"?`, so the spelling that actually works reads as a
          -- type error. Proven empirically by Phase 5's R1 (above); do not
          -- "fix" this to the annotated shape.
          ---@diagnostic disable-next-line: assign-type-mismatch
          layout = { preview = false },
          actions = { ucw_bufdelete = bufdelete },
          win = {
            input = {
              keys = {
                -- All of snacks' delete bindings for this source, not just the
                -- one Telescope happened to use: `<c-d>` is ours, `<c-x>` and
                -- the list's `dd` are snacks' defaults and would otherwise
                -- bypass the jumplist preference above on adjacent keys.
                -- `<c-d>` shadows `list_scroll_down` in this picker only,
                -- which is what Telescope's binding did too.
                ['<c-d>'] = { 'ucw_bufdelete', mode = { 'n', 'i' } },
                ['<c-x>'] = { 'ucw_bufdelete', mode = { 'n', 'i' } },
              },
            },
            list = { keys = { ['dd'] = 'ucw_bufdelete' } },
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
  -- `<leader>s` = search (Phase 9, D3): every content picker under one
  -- prefix, LazyVim's namespace. The four LSP-backed members (`ss`/`sS`/
  -- `sd`/`sD`) are in `which-key.lua` so their rhs resolve through
  -- `ucw.lsp.actions`; `sm` (messages) is in `noice.lua`. The `<leader>T`
  -- tree this replaces had exactly one member (`Th`, now `sc`).
  --
  -- Deliberately *not* here: a key per remaining snacks source. The
  -- `s<space>` picker-of-pickers reaches the whole long tail, which is what
  -- keeps this tree small (design doc §2.3).
  keys = {
    {
      '<C-p>',
      function()
        -- `smart` minus its `buffers` finder (Phase 9 D3, r2.1): the
        -- frecency and cwd-bonus boosts live in the matcher and survive;
        -- open buffers do not get a quiet second door - `<leader>bb` is the
        -- only one. `multi` is the composition mechanism; the annotated
        -- `finders` field on smart.Config has no consumer (measured).
        Snacks.picker.smart { multi = { 'recent', 'files' } }
      end,
      desc = 'Find file (frecency)',
      silent = true,
    },
    {
      '<M-S-f>',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Find in CWD',
      silent = true,
    },
    -- `lines` is snacks' name for what Telescope called
    -- `current_buffer_fuzzy_find`.
    {
      '<M-f>',
      function()
        Snacks.picker.lines()
      end,
      desc = 'Find in File',
      silent = true,
    },
    -- `<leader>f` = find *files* (Phase 9, D3); content search is
    -- `<leader>s`. No `fb`: buffers keep exactly one door, `<leader>bb`.
    {
      '<leader>ff',
      function()
        Snacks.picker.files()
      end,
      desc = 'Find files',
      silent = true,
    },
    {
      '<leader>fr',
      function()
        Snacks.picker.recent()
      end,
      desc = 'Recent files',
      silent = true,
    },
    {
      '<leader>fg',
      function()
        Snacks.picker.git_files()
      end,
      desc = 'Git files',
      silent = true,
    },
    {
      '<leader>sg',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Grep in CWD',
      silent = true,
    },
    {
      '<leader>sb',
      function()
        Snacks.picker.lines()
      end,
      desc = 'Search lines in file',
      silent = true,
    },
    {
      '<leader>sw',
      function()
        Snacks.picker.grep_word()
      end,
      desc = 'Grep word under cursor (or selection)',
      mode = { 'n', 'x' },
      silent = true,
    },
    {
      '<leader>sc',
      function()
        Snacks.picker.command_history()
      end,
      desc = 'Command history',
      silent = true,
    },
    {
      '<leader>sk',
      function()
        Snacks.picker.keymaps()
      end,
      desc = 'Search keymaps',
      silent = true,
    },
    {
      '<leader>sh',
      function()
        Snacks.picker.help()
      end,
      desc = 'Search help',
      silent = true,
    },
    {
      '<leader>s<space>',
      function()
        Snacks.picker()
      end,
      desc = 'All pickers',
      silent = true,
    },
    {
      '<leader>bb',
      function()
        Snacks.picker.buffers()
      end,
      desc = 'Go to buffer',
      silent = true,
    },
    -- A single key, not a tree (Phase 9, D7): the old three-key
    -- notifications group is spread by function now - search is
    -- `<leader>sm`, dismiss is `<leader>un` - leaving history as the only
    -- direct member, on the LazyVim-shaped single binding.
    {
      '<leader>n',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification history',
      silent = true,
    },
  },
  config = config,
}
