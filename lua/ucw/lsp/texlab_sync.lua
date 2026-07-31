-- SyncTeX glue between texlab, latexmk and zathura.
--
-- Forward search (editor -> viewer) is a texlab setting; backward search
-- (viewer -> editor) is zathura invoking `nvim --remote-expr` against this
-- Neovim instance, so the callback has to be reachable from an expression
-- string. That is why it stays a global: it is an external contract with
-- another process, not an internal API.

local M = {}

---@param filename string
---@param line? number 1-based line, or <1 to keep the cursor line
---@param col? number 0-based column, or <0 to keep the cursor column
---@return string always empty, to keep `--remote-expr` quiet
function _G.texlab_backward_search(filename, line, col)
  vim.cmd([[drop ]] .. filename)

  local l, c = unpack(vim.api.nvim_win_get_cursor(0))
  if not line or line < 1 then
    line = l
  end
  if not col or col < 0 then
    col = c
  end
  vim.api.nvim_win_set_cursor(0, { line, col })

  -- unfold the cursor line, then centre it
  vim.cmd([[normal! zv]])
  vim.cmd([[normal! zz]])

  return ''
end

---texlab's `forwardSearch` settings for zathura.
---@return table
function M.forward_search()
  return {
    executable = 'zathura',
    args = {
      '--synctex-editor-command',
      string.format(
        [[nvim --server %s --remote-expr 'v:lua.texlab_backward_search("%%{input}", %%{line}, %%{column})']],
        vim.v.servername
      ),
      '--synctex-forward',
      '%l:1:%f',
      '%p',
    },
  }
end

return M
