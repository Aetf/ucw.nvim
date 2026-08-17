-- noice is what `vim.notify` actually points at (it saves the previous value
-- and installs its own in `noice/source/notify.lua`), and it captures the rest
-- of the message traffic too - cmdline echoes, LSP messages, errors - which is
-- what makes `:Noice` a history of *everything* rather than only of
-- `vim.notify()` calls.
--
-- Rendering happens in a *backend*. Phase 5 removed nvim-notify, which used to
-- be that backend; snacks.notifier is now.
return {
  'folke/noice.nvim',
  lazy = false,
  -- Phase 8 (D1): moved here verbatim from `which-key.lua`; the `<leader>n`
  -- group header stays there. `<leader>nh` (snacks notifier history) is in
  -- `snacks.lua` - the notification *tree* spans two owners.
  --
  -- The pain point `<leader>nn` answers: message history used to be
  -- effectively unreadable. `Snacks.picker.noice` is the superset - noice
  -- registers that picker source itself when snacks.picker is present, and
  -- noice sees *all* message traffic, not only `vim.notify()` calls.
  keys = {
    {
      '<leader>nn',
      function()
        -- noice registers this picker source with snacks at runtime
        -- (`noice/init.lua`), so no annotation can know the field exists.
        ---@diagnostic disable-next-line: undefined-field
        Snacks.picker.noice()
      end,
      desc = 'Search all messages',
      silent = true,
    },
    -- Under the toggle/UI prefix (Phase 9, D4/D7): not a toggle, but "make
    -- the popups go away" is a UI action and LazyVim's own `un` letter.
    {
      '<leader>un',
      function()
        require('noice').cmd('dismiss')
      end,
      desc = 'Dismiss notifications',
      silent = true,
    },
  },
  dependencies = {
    'MunifTanjim/nui.nvim',
    'folke/snacks.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('noice').setup {
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
      },
      views = {
        -- Pin the backend rather than relying on noice's default
        -- `{ "snacks", "notify" }` to resolve. That list is a fallback chain
        -- whose second entry now names a plugin that is not installed, so if
        -- `SnacksView:is_available()` ever went false (it tests
        -- `Snacks.config.notifier.enabled`, nothing more) notifications would
        -- quietly degrade to the plain "mini" view instead of failing loudly.
        notify = { backend = 'snacks' },
      },
      -- `notify = { enabled = true, view = "notify" }` used to be spelled out
      -- here. Both are noice's own defaults.
      presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
      },
    }
  end,
}
