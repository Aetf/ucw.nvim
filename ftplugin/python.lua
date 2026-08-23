-- No `lsp_format` override: unlike `lua_ls`, the LSP fallback client here
-- (`ruff`) is the same tool `ruff_format` shells out to, so falling back to
-- it if the named formatter were ever unavailable reaches the right tool
-- anyway, not a trap.
require('conform').formatters_by_ft.python = { 'ruff_format' }

-- Cell navigation, buffer-local because `# %%` is Python's comment syntax and
-- nothing else in this config marks cells (Phase 9.5, T6). `[`/`]` + a
-- category letter is the one form this config uses for "previous / next in a
-- sequence"; `h` is the letter the cell textobject already carries in mini.ai
-- (`ah`/`ih`), so `[h`/`]h` needs no vocabulary of its own.
for lhs, dir in pairs { ['[h'] = 'prev', [']h'] = 'next' } do
  vim.keymap.set({ 'n', 'x' }, lhs, function()
    require('ucw.keys.actions').cell_jump(dir)
  end, {
    buffer = true,
    desc = ('Go to %s ipython cell'):format(dir == 'prev' and 'previous' or 'next'),
  })
end
