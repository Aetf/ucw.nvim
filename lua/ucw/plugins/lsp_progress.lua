return {
  'linrongbin16/lsp-progress.nvim',
  event = 'User UcwLspEnable',
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
    vim.api.nvim_create_autocmd("User", {
      group = 'lualine_augroup',
      pattern = 'LspProgressStatusUpdated',
      callback = lualine.refresh,
    })
  end,
}
