-- Server progress spinner in lualine.
--
-- `LspAttach` rather than the LSP `ft` trigger: setup costs 3-12 ms (it
-- rebuilds and re-applies the whole lualine config), and the component has
-- nothing to show until a client exists anyway. Attaching is already past the
-- point where the file is on screen, so this cost is never on the path to a
-- rendered buffer.
return {
  'linrongbin16/lsp-progress.nvim',
  cond = require('ucw.targets').is_full_ui,
  event = 'LspAttach',
  dependencies = { 'nvim-lualine/lualine.nvim' },
  config = function()
    local lsp_progress = require('lsp-progress')
    lsp_progress.setup {}

    -- update lualine to include the component
    local lualine = require('lualine')
    local config = lualine.get_config()
    table.insert(config.sections.lualine_x, 1, {
      lsp_progress.progress,
    })

    -- apply lualine config
    lualine.setup(config)

    -- listen lsp-progress event and refresh lualine
    vim.api.nvim_create_augroup('lualine_augroup', { clear = true })
    vim.api.nvim_create_autocmd('User', {
      group = 'lualine_augroup',
      pattern = 'LspProgressStatusUpdated',
      -- `lualine.refresh` takes an options table and returns nothing, which is
      -- not the `fun(args): boolean?` shape an autocmd callback is annotated
      -- with. Passing it directly is intentional: the callback args are simply
      -- ignored, and a wrapper would only exist to satisfy the annotation.
      ---@diagnostic disable-next-line: assign-type-mismatch
      callback = lualine.refresh,
    })
  end,
}
