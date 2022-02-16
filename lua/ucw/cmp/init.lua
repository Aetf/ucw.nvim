local M = {}

-- Centralized source configuration
local sources = {
  buffer = {
    name = 'buffer',
    option = {
      keyword_length = 6,
    }
  },
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

function M.config()
  vim.opt.completeopt = 'menu,menuone,noselect'

  local cmp = require('cmp')
  cmp.setup({
    experimental = {
      ghost_text = true,
    },
    preselect = cmp.PreselectMode.Item,
    mapping = {
      ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
      ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
      ['<M-.>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
      ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
      ['<C-e>'] = cmp.mapping({
	i = cmp.mapping.abort(),
	c = cmp.mapping.close(),
      }),
      ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
      ["<Tab>"] = cmp.mapping(function(fallback)
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
    },
    sources = cmp.config.sources({
      sources.lsp_signature,
      sources.lsp,
      sources.vim_lua,
      sources.snip,
      sources.path,
    }, {
      sources.buffer,
    }),
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    sources = cmp.config.sources({
      sources.path,
    }, {
      sources.cmdline,
    })
  })

end

return M
