-- disable hard wrap
vim.opt_local.textwidth = 0
vim.opt_local.wrap = true

-- one sentence per line formatting
function latexformatexpr(lnum, count)
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end
  local start_line = lnum
  local end_line = start_line + count - 1
  -- first join all lines together
  -- TODO: detect the presence of comment lines and skip those (both starting with % and containing % in the middle,
  -- those lines are unsafe to join)
  vim.cmd(string.format([[silent %d,%djoin]], start_line, end_line))
  -- end of sentence:
  --   either a single char [.!?:;]
  --   or                   \|
  --   a senquence          \.\\@
  -- and they must followed by
  --   non-empty spaces     \zs\s\+\ze\S
  vim.cmd(string.format([[silent %ds/[.!?:;]\zs\s\+\ze\S\|\.\\@\zs\s\+\ze\S/\r/g]], start_line))
  vim.cmd("nohlsearch")
  -- do not run builtin formatter
  return 0
end
vim.opt_local.formatexpr = 'v:lua.latexformatexpr(v:lnum, v:count)'
