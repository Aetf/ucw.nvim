-- NOTE: this whole cluster (nvim-cmp + sources + luasnip) is faithfully
-- migrated as-is from the old engine; it is replaced wholesale by blink.cmp
-- + native vim.snippet in a later modernization phase.

local sources = {
  buffer = { name = 'buffer', option = { keyword_length = 6 } },
  path = { name = 'path' },
  cmdline = { name = 'cmdline' },
  lsp_signature = { name = 'nvim_lsp_signature_help' },
  lsp = { name = 'nvim_lsp' },
  snip = { name = 'luasnip' },
  vim_lua = { name = 'nvim_lua' },
}

local function has_words_before()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local function config()
  vim.opt.completeopt = 'menu,menuone,noselect'

  local cmp = require('cmp')
  cmp.setup({
    experimental = {
      ghost_text = true,
    },
    preselect = cmp.PreselectMode.Item,
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
      ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
      ['<M-.>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
      ['<C-y>'] = cmp.config.disable,
      ['<C-e>'] = cmp.mapping({
        i = cmp.mapping.abort(),
        c = cmp.mapping.close(),
      }),
      ['<CR>'] = cmp.mapping.confirm({ select = false }),
      ['<Tab>'] = cmp.mapping(function(fallback)
        local has_luasnip, luasnip = pcall(require, 'luasnip')
        if cmp.visible() then
          cmp.select_next_item()
        elseif has_luasnip and luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        elseif has_words_before() then
          cmp.complete()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        local has_luasnip, luasnip = pcall(require, 'luasnip')
        if cmp.visible() then
          cmp.select_prev_item()
        elseif has_luasnip and luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = cmp.config.sources({
      sources.lsp_signature,
      sources.lsp,
      sources.vim_lua,
      sources.snip,
      sources.path,
    }, {
      sources.buffer,
    }),
    sorting = {
      comparators = {
        cmp.config.compare.offset,
        cmp.config.compare.exact,
        cmp.config.compare.score,
        require('cmp-under-comparator').under,
        cmp.config.compare.kind,
        cmp.config.compare.sort_text,
        cmp.config.compare.length,
        cmp.config.compare.order,
      },
    },
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline({}),
    sources = cmp.config.sources({
      sources.path,
    }, {
      sources.cmdline,
    })
  })
end

return {
  'hrsh7th/nvim-cmp',
  lazy = false,
  dependencies = {
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-cmdline',
    'hrsh7th/cmp-nvim-lua',
    'lukas-reineke/cmp-under-comparator',
    { 'windwp/nvim-autopairs', config = function()
      require('nvim-autopairs').setup {
        check_ts = true,
        enable_check_bracket_line = true,
      }
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local ok, cmp = pcall(require, 'cmp')
      if ok then
        cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done({}))
      end
    end },
  },
  config = config,
}
